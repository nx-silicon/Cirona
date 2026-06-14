#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pdk_config_extractor.py
=======================

从一个 SPICE 模型库（.lib / .spice / model card）里，**确定性地**提取出
Cirona 所需的 ``pdk_config.json`` 骨架。

设计原则——诚实地区分"能可靠提取"和"提取不到"：

  能确定性提取（来自模型文件本身的规整语法）：
    - 工艺角 corner 列表          （扫顶层 ``.lib <name> ... .endl``）
    - 器件清单（NMOS/PMOS 及变体）（扫 ``.subckt`` + 关联的 ``.model``）
    - 每个器件的端口顺序          （``.subckt`` 端口行）
    - W / L 的最小/最大值          （跨所有 binned ``.model`` 聚合 wmin/wmax/lmin/lmax）
    - 近似典型 Vth                （取 BSIM 的 ``vth0`` 参数，标注为近似）
    - 氧化层厚度                  （``toxm`` / ``toxe``）
    - 噪声 / 失配开关             （``fnoimod`` / ``tnoimod`` / mismatch include）
    - 单位约定（米 vs µm）        （由 lmin/lmax 数量级推断）

  提取不到、留 TODO 让你人工补（模型文件里通常没有）：
    - 供电电压 core/io 的标称与上下限
    - 温度范围的上下限（标称可从 tnom 推断）
    - license / version / 描述（尽力从文件头注释提取）
    - 精确的"典型工作 Vth"（vth0 只是零偏近似）

用法：
    python pdk_config_extractor.py <顶层模型文件> [-o pdk_config.json] [--pdk-name 名称]

例：
    python pdk_config_extractor.py sky130.lib.spice -o pdk_config.json --pdk-name "SkyWater SKY130"

输出的 JSON 里，``_extraction`` 字段会列出本次提取的 TODO 与告警，请务必人工核对。

无第三方依赖，仅用 Python 标准库（Python 3.7+）。
"""

import argparse
import json
import os
import re
import sys
from collections import OrderedDict

TOOL_NAME = "pdk_config_extractor"
TOOL_VERSION = "0.1"

# ---------------------------------------------------------------------------
# 1. SPICE 预处理：读取、去注释、合并续行、递归展开 .include
# ---------------------------------------------------------------------------

def _read_text(path):
    """读文件，UTF-8 优先，失败回退 latin-1（SPICE 文件常含非 ASCII 注释）。"""
    for enc in ("utf-8", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as fh:
                return fh.read()
        except UnicodeDecodeError:
            continue
    # 最后兜底：忽略错误
    with open(path, "r", encoding="utf-8", errors="ignore") as fh:
        return fh.read()


def _logical_lines(text):
    """把物理行整理成逻辑行：丢弃整行注释（``*`` 开头）与空行，
    把续行（``+`` 开头）拼接到上一逻辑行，最后剥掉行内 ``$`` 注释。"""
    logical = []
    for raw in text.splitlines():
        if not raw.strip():
            continue
        stripped = raw.strip()
        if stripped.startswith("*"):          # 整行注释
            continue
        if stripped.startswith("+"):           # 续行
            cont = stripped[1:].strip()
            if logical:
                logical[-1] = logical[-1] + " " + cont
            else:
                logical.append(cont)
        else:
            logical.append(stripped)
    cleaned = []
    for line in logical:
        idx = line.find("$")                   # 行内注释
        if idx > 0:
            line = line[:idx].strip()
        if line:
            cleaned.append(line)
    return cleaned


_INCLUDE_RE = re.compile(r'^\.inc(?:lude)?\s+["\']?([^"\'\s]+)["\']?', re.IGNORECASE)


def expand(path, seen=None, missing=None):
    """递归展开 ``.include``，返回 ``[(logical_line, source_path), ...]``。
    用绝对路径集合 ``seen`` 防止重复/循环引用。"""
    seen = seen if seen is not None else set()
    missing = missing if missing is not None else []
    abspath = os.path.abspath(path)
    if abspath in seen:
        return []
    seen.add(abspath)
    if not os.path.isfile(abspath):
        missing.append(path)
        return []
    base = os.path.dirname(abspath)
    out = []
    for line in _logical_lines(_read_text(abspath)):
        m = _INCLUDE_RE.match(line)
        if m:
            inc = m.group(1)
            inc_path = inc if os.path.isabs(inc) else os.path.join(base, inc)
            out.extend(expand(inc_path, seen, missing))
            continue
        out.append((line, abspath))
    return out


# ---------------------------------------------------------------------------
# 2. 解析 corner / subckt / model
# ---------------------------------------------------------------------------

_LIB_DEF_RE = re.compile(r'^\.lib\s+(\S+)\s*$', re.IGNORECASE)


def extract_corners(toplevel_path):
    """从顶层文件提取 corner 名：``.lib <name>``（单 token 到行尾 = 定义段；
    ``.lib '<file>' <name>`` 是引用，被排除）。"""
    corners = []
    for line in _logical_lines(_read_text(toplevel_path)):
        m = _LIB_DEF_RE.match(line)
        if not m:
            continue
        name = m.group(1)
        # 排除引用形式与看起来像文件名的 token
        if name[0] in "'\"" or "/" in name or "\\" in name or "." in name:
            continue
        corners.append(name)
    return list(OrderedDict.fromkeys(corners))


def _parse_ports(tokens):
    """从 ``.subckt name p1 p2 ... [param=val]`` 的 token 列表中取端口名。
    端口 = name 之后、第一个参数赋值（``x = y`` 或 ``x=y``）之前的 token。"""
    ports = []
    rest = tokens[2:]
    for i, tok in enumerate(rest):
        if tok == "=" or "=" in tok:
            break
        if i + 1 < len(rest) and rest[i + 1] == "=":   # 下一个是 '='，说明 tok 是参数名
            break
        ports.append(tok)
    return ports


_NUM_PARAM_RE = re.compile(r'([A-Za-z]\w*)\s*=\s*([-+]?[0-9][-+0-9.eE]*)')


def _parse_params(line):
    """提取 ``name = number`` 形式的纯数值参数；``name={expr}`` 这类表达式跳过。"""
    params = {}
    for m in _NUM_PARAM_RE.finditer(line):
        key = m.group(1).lower()
        try:
            params[key] = float(m.group(2))
        except ValueError:
            pass
    return params


def _mos_model_ref(tokens):
    """从 subckt 内的 MOS 实例行 ``m<inst> n1 n2 n3 n4 <model> param=...``
    里取被引用的 model 名（端口之后、第一个参数之前的最后一个 token）。"""
    pre = []
    rest = tokens[1:]
    for i, tok in enumerate(rest):
        if tok == "=" or "=" in tok:
            break
        if i + 1 < len(rest) and rest[i + 1] == "=":
            break
        pre.append(tok)
    return pre[-1] if len(pre) >= 2 else None


def parse(statements):
    """解析展开后的语句，返回 (subckts, models)。
    subckts: name -> {ports, models_used}
    models:  name -> {type, params}
    同名定义只保留首次出现（多 corner 重复 include 时去重）。"""
    subckts = OrderedDict()
    models = OrderedDict()
    cur = None
    for line, _src in statements:
        low = line.lower()
        if low.startswith(".subckt"):
            toks = line.split()
            if len(toks) < 2:
                continue
            name = toks[1]
            cur = subckts.setdefault(name, {"name": name,
                                            "ports": _parse_ports(toks),
                                            "models_used": []})
        elif low.startswith(".ends"):
            cur = None
        elif low.startswith(".model"):
            toks = line.split()
            if len(toks) < 3:
                continue
            mname = toks[1]
            mtype = toks[2].lower()
            entry = models.setdefault(mname, {"type": mtype, "params": {}})
            entry["params"].update(_parse_params(line))   # 合并多行/多段参数
        elif cur is not None and low and low[0] == "m":
            ref = _mos_model_ref(line.split())
            if ref:
                cur["models_used"].append(ref)
    return subckts, models


# ---------------------------------------------------------------------------
# 3. 组装器件 & 配置
# ---------------------------------------------------------------------------

MOS_TYPES = {"nmos", "pmos"}


def _match_models(ref, models):
    """匹配一个 model 引用基名对应的所有 binned model（精确或前缀匹配）。"""
    hit = []
    for mname, mo in models.items():
        if mname == ref or mname.startswith(ref):
            hit.append((mname, mo))
    return hit


def _aggregate_wl(matched):
    """跨所有 bin 聚合 W/L 范围。"""
    lmin = [mo["params"]["lmin"] for _, mo in matched if "lmin" in mo["params"]]
    lmax = [mo["params"]["lmax"] for _, mo in matched if "lmax" in mo["params"]]
    wmin = [mo["params"]["wmin"] for _, mo in matched if "wmin" in mo["params"]]
    wmax = [mo["params"]["wmax"] for _, mo in matched if "wmax" in mo["params"]]
    out = {}
    if lmin and lmax:
        out["L"] = {"min": min(lmin), "max": max(lmax)}
    if wmin and wmax:
        out["W"] = {"min": min(wmin), "max": max(wmax)}
    return out


def _first_param(matched, key):
    for _, mo in matched:
        if key in mo["params"]:
            return mo["params"][key]
    return None


def _device_key(model_name, dtype):
    """根据模型名里的特征生成一个可读的器件 key，如 nmos / pmos_lvt / nmos_5v。"""
    n = model_name.lower()
    base = dtype  # nmos / pmos
    suffix = ""
    if "lvt" in n:
        suffix = "_lvt"
    elif "hvt" in n:
        suffix = "_hvt"
    if any(t in n for t in ("g5v0", "05v0", "5v0", "_5v", "03v3", "3v3")):
        suffix = suffix or "_io"
    return base + suffix


def _fmt_meters(value):
    """把米制数值格式化成易读的 µm 字符串（同时保留含义）。"""
    if value is None:
        return None
    um = value * 1e6
    return "{:g}u".format(um)


def build_devices(subckts, models, warnings):
    """从 subckt + model 组装晶体管器件列表。非 MOS（电容/电阻等）跳过。"""
    devices = OrderedDict()
    counts = {"nmos": 0, "pmos": 0, "non_mos_subckt": 0, "bare_model": 0}
    used_models = set()

    # --- 情形 A：subckt 封装（多数现代 PDK） ---
    for sub in subckts.values():
        matched = []
        types = set()
        for ref in dict.fromkeys(sub["models_used"]):
            hit = _match_models(ref, models)
            matched.extend(hit)
            types.update(mo["type"] for _, mo in hit)
        mos = types & MOS_TYPES
        if not mos:
            counts["non_mos_subckt"] += 1
            continue
        dtype = "nmos" if "nmos" in mos else "pmos"
        for mname, _ in matched:
            used_models.add(mname)
        counts[dtype] += 1

        wl = _aggregate_wl(matched)
        vth0 = _first_param(matched, "vth0")
        tox = _first_param(matched, "toxm") or _first_param(matched, "toxe")
        ports = [p.upper() for p in sub["ports"]]

        key = _device_key(sub["name"], dtype)
        # 同 key 去重（取首个；罕见碰撞时加序号）
        uniq = key
        idx = 2
        while uniq in devices:
            uniq = "{}_{}".format(key, idx)
            idx += 1

        entry = OrderedDict()
        entry["model_name"] = sub["name"]
        entry["type"] = dtype
        entry["terminals"] = ports
        entry["spice_order"] = " ".join(ports + [sub["name"], "W=", "L=", "nf=", "m="])
        if "W" in wl:
            entry["W"] = {"min": _fmt_meters(wl["W"]["min"]),
                          "max": _fmt_meters(wl["W"]["max"]), "unit": "meters"}
        if "L" in wl:
            entry["L"] = {"min": _fmt_meters(wl["L"]["min"]),
                          "max": _fmt_meters(wl["L"]["max"]), "unit": "meters"}
        if vth0 is not None:
            entry["Vth"] = {"typical": round(vth0, 4), "unit": "V",
                            "_note": "approx. from BSIM vth0 (zero-bias); verify by simulation"}
        if tox is not None:
            entry["oxide_thickness"] = "{:g}nm".format(tox * 1e9)
        devices[uniq] = entry

    # --- 情形 B：裸 .model（无 subckt 封装），端口按 SPICE 默认 D G S B ---
    for mname, mo in models.items():
        if mo["type"] not in MOS_TYPES or mname in used_models:
            continue
        counts["bare_model"] += 1
        dtype = mo["type"]
        matched = [(mname, mo)]
        wl = _aggregate_wl(matched)
        vth0 = _first_param(matched, "vth0")
        key = _device_key(mname, dtype)
        uniq = key
        idx = 2
        while uniq in devices:
            uniq = "{}_{}".format(key, idx)
            idx += 1
        entry = OrderedDict()
        entry["model_name"] = mname
        entry["type"] = dtype
        entry["terminals"] = ["D", "G", "S", "B"]
        entry["spice_order"] = "D G S B {} W= L=".format(mname)
        entry["_note"] = "bare .model (no .subckt); terminal order assumed D G S B — verify"
        if "W" in wl:
            entry["W"] = {"min": _fmt_meters(wl["W"]["min"]),
                          "max": _fmt_meters(wl["W"]["max"]), "unit": "meters"}
        if "L" in wl:
            entry["L"] = {"min": _fmt_meters(wl["L"]["min"]),
                          "max": _fmt_meters(wl["L"]["max"]), "unit": "meters"}
        if vth0 is not None:
            entry["Vth"] = {"typical": round(vth0, 4), "unit": "V",
                            "_note": "approx. from BSIM vth0; verify by simulation"}
        devices[uniq] = entry

    return devices, counts


def detect_special_notes(statements, models):
    """检测单位约定、噪声、失配等特殊说明。"""
    notes = OrderedDict()

    # 单位：看任一 MOS model 的 lmin 数量级
    lmin_vals = []
    for mo in models.values():
        if mo["type"] in MOS_TYPES and "lmin" in mo["params"]:
            lmin_vals.append(mo["params"]["lmin"])
    if lmin_vals:
        if max(lmin_vals) < 1e-3:
            notes["units"] = ("W/L 在模型中为米（SI 单位）。写网表时用 L=0.15e-6，"
                              "不要写 L=0.15u。")
        else:
            notes["units"] = ("W/L 数量级看起来不是米，可能是 µm —— 请人工确认单位约定。")

    # subckt 封装
    has_subckt = any(low_startswith(s, ".subckt") for s, _ in statements)
    if has_subckt:
        notes["subcircuit"] = "器件为 .subckt 封装，实例化用 X 前缀，例如 XM1 D G S B <model> W=.. L=.."

    blob = "\n".join(s.lower() for s, _ in statements[:20000])  # 取样，避免超大拼接
    if "fnoimod" in blob or "tnoimod" in blob:
        notes["noise"] = "模型含 BSIM 噪声模型（fnoimod/tnoimod）。"
    if "mismatch" in blob or "mc_mm_switch" in blob:
        notes["mismatch"] = "模型含失配/Monte Carlo 参数（如 mc_mm_switch / mismatch corner）。"
    return notes


def low_startswith(line, prefix):
    return line[:len(prefix)].lower() == prefix


def extract_header_meta(toplevel_path):
    """尽力从文件头注释提取 license / 描述（不可靠，仅作草稿）。"""
    meta = {}
    text = _read_text(toplevel_path)
    head = "\n".join(text.splitlines()[:40])
    if re.search(r'apache', head, re.IGNORECASE):
        meta["license"] = "Apache-2.0"
    elif re.search(r'\bMIT\b', head):
        meta["license"] = "MIT"
    elif re.search(r'GPL', head, re.IGNORECASE):
        meta["license"] = "GPL"
    return meta


def extract_tnom(models):
    for mo in models.values():
        if mo["type"] in MOS_TYPES and "tnom" in mo["params"]:
            return mo["params"]["tnom"]
    return None


def build_config(toplevel_path, pdk_name, corners, devices, dev_counts,
                 special_notes, models, missing):
    cfg = OrderedDict()
    todo = []
    warnings = []

    header = extract_header_meta(toplevel_path)

    cfg["name"] = pdk_name or "TODO: 工艺名称"
    if not pdk_name:
        todo.append("name: 填写工艺名称")
    cfg["version"] = "TODO: 版本号"
    todo.append("version: 填写 PDK 版本")
    cfg["description"] = "TODO: 一句话描述"
    todo.append("description: 填写工艺简介")
    cfg["license"] = header.get("license", "TODO: license")
    if "license" not in header:
        todo.append("license: 未能从文件头识别，请填写")
    cfg["model_file"] = os.path.basename(toplevel_path)
    cfg["model_format"] = "lib_section" if corners else "plain"

    cfg["supply_voltage"] = {
        "core": {"nominal": "TODO", "min": "TODO", "max": "TODO"},
        "io": {"nominal": "TODO"},
    }
    todo.append("supply_voltage: 模型文件无此信息，请按工艺手册填写 core/io 电压")

    tnom = extract_tnom(models)
    cfg["temperature"] = {
        "nominal": tnom if tnom is not None else "TODO",
        "min": "TODO",
        "max": "TODO",
        "unit": "Celsius",
    }
    todo.append("temperature.min/max: 模型只含标称温度(tnom)，上下限请按工艺手册填写")

    cfg["devices"] = devices
    if not devices:
        warnings.append("未识别到任何 NMOS/PMOS 器件 —— 请检查输入文件是否为器件模型库。")
    elif len(devices) > 8:
        warnings.append(
            "识别到 {} 个 MOS 变体（可能含 RF / ESD / 分立器件）；".format(len(devices))
            + "pdk_config 通常只精选常用的几个核心器件，建议人工裁剪 devices。")

    cfg["corner_models"] = OrderedDict()
    cfg["corner_models"]["file"] = os.path.basename(toplevel_path)
    cfg["corner_models"]["format"] = "lib_section" if corners else "plain"
    if corners:
        cfg["corner_models"]["usage"] = ".lib '{}' {}".format(
            os.path.basename(toplevel_path), corners[0])
        cfg["corner_models"]["corners"] = corners
    else:
        warnings.append("未在顶层文件发现 .lib corner 段；corner 列表为空，请确认。")

    if special_notes:
        cfg["special_notes"] = special_notes

    # 每个器件的 Vth 都是近似，统一提醒一次
    if any("Vth" in d for d in devices.values()):
        todo.append("Vth: 各器件 Vth 取自 vth0(零偏近似)，建议用仿真核对典型工作 Vth")

    cfg["_extraction"] = OrderedDict()
    cfg["_extraction"]["tool"] = "{} v{}".format(TOOL_NAME, TOOL_VERSION)
    cfg["_extraction"]["device_counts"] = dev_counts
    if missing:
        warnings.append("有 {} 个 .include 文件未找到（路径问题？），解析可能不完整。".format(len(missing)))
        cfg["_extraction"]["missing_includes"] = missing[:20]
    cfg["_extraction"]["todo"] = todo
    cfg["_extraction"]["warnings"] = warnings
    cfg["_extraction"]["disclaimer"] = (
        "本文件由脚本自动提取，仅为草稿骨架。带 TODO 的字段必须人工补全；"
        "端口顺序与 W/L 单位务必人工核对后再用于设计。")
    return cfg, todo, warnings


# ---------------------------------------------------------------------------
# 4. CLI
# ---------------------------------------------------------------------------

def main(argv=None):
    # Windows 控制台默认可能是 GBK，重配为 UTF-8，避免中文/emoji 输出抛错
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass
    parser = argparse.ArgumentParser(
        description="从 SPICE 模型库提取 Cirona pdk_config.json 骨架（草稿）。")
    parser.add_argument("model_file", help="顶层 SPICE 模型库文件（.lib/.spice）")
    parser.add_argument("-o", "--output", default="pdk_config.json",
                        help="输出 JSON 路径（默认 pdk_config.json）")
    parser.add_argument("--pdk-name", default=None, help="工艺名称（可选，建议填）")
    args = parser.parse_args(argv)

    if not os.path.isfile(args.model_file):
        print("错误：找不到输入文件 {}".format(args.model_file), file=sys.stderr)
        return 2

    print("[1/4] 展开 .include …")
    missing = []
    statements = expand(args.model_file, missing=missing)
    print("      逻辑语句 {} 条；缺失 include {} 个".format(len(statements), len(missing)))

    print("[2/4] 提取 corner …")
    corners = extract_corners(args.model_file)
    print("      corner: {}".format(", ".join(corners) if corners else "(无)"))

    print("[3/4] 解析 .subckt / .model …")
    subckts, models = parse(statements)
    print("      subckt {} 个，model {} 个".format(len(subckts), len(models)))

    print("[4/4] 组装器件与配置 …")
    warnings = []
    devices, dev_counts = build_devices(subckts, models, warnings)
    special_notes = detect_special_notes(statements, models)
    cfg, todo, warns = build_config(args.model_file, args.pdk_name, corners,
                                    devices, dev_counts, special_notes, models, missing)

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(cfg, fh, ensure_ascii=False, indent=2)

    print("\n完成 → {}".format(args.output))
    print("识别器件：NMOS {} / PMOS {}（另跳过非 MOS subckt {} 个）".format(
        dev_counts["nmos"], dev_counts["pmos"], dev_counts["non_mos_subckt"]))
    if warns:
        print("\n[!] 告警：")
        for w in warns:
            print("   - " + w)
    print("\n[TODO] 需人工补全/核对（详见 JSON 的 _extraction.todo）：")
    for t in todo:
        print("   - " + t)
    print("\n提示：带 TODO 的字段必须人工补；端口顺序与 W/L 单位务必核对后再用。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

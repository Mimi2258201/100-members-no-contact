#!/usr/bin/env python3
import collections
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.environ.get("CHECK_ROOT") or os.getcwd())

ERROR, WARN, NOTICE = "error", "warning", "notice"
_RANK = {ERROR: 0, WARN: 1, NOTICE: 2}
findings = []


def add(check, sev, msg, file=None, line=None, title=None):
    findings.append(dict(check=check, sev=sev, msg=msg, file=file, line=line, title=title or check))


def tracked_files():
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True)
    if out.returncode == 0:
        return [p for p in out.stdout.decode("utf-8", "replace").split("\0") if p]
    files = []
    for dp, _, fn in os.walk(ROOT):
        if "/.git" in dp or "/.godot" in dp:
            continue
        for f in fn:
            files.append(os.path.relpath(os.path.join(dp, f), ROOT))
    return files


TEXT_EXT = {".gd", ".tscn", ".tres", ".import", ".uid", ".cfg", ".godot", ".md",
            ".json", ".txt", ".cs", ".yml", ".yaml", ".csv", ".ini", ".xml",
            ".html", ".gdshader", ".editorconfig"}


def is_text(path):
    if path.endswith((".uid", ".gitignore", ".gitattributes")):
        return True
    return os.path.splitext(path)[1].lower() in TEXT_EXT


def read(path):
    try:
        with open(os.path.join(ROOT, path), "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def first_line(path):
    txt = read(path)
    nl = txt.find("\n")
    return txt if nl < 0 else txt[:nl]


UID_DECL = re.compile(r'^\[gd_(?:scene|resource)[^\]]*\buid="(uid://[0-9a-z]+)"')
UID_IMPORT = re.compile(r'^uid="?(uid://[0-9a-z]+)"?', re.M)
EXT_UID = re.compile(r'\[ext_resource[^\]]*\buid="(uid://[0-9a-z]+)"')
RESPATH = re.compile(r'path="(res://[^"]+)"')
SCENE_FMT = re.compile(r'^\[gd_scene[^\]]*\bformat=(\d+)')

IMPORTABLE = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".svg", ".mp3",
              ".wav", ".ogg", ".ttf", ".otf", ".woff", ".woff2", ".gltf", ".glb", ".obj"}
WIN_ILLEGAL = re.compile(r'[:*?"<>|]')


def build_uid_index(files):
    decl = collections.defaultdict(list)
    for p in files:
        ext = os.path.splitext(p)[1].lower()
        if ext in (".tscn", ".tres"):
            m = UID_DECL.match(first_line(p))
            if m:
                decl[m.group(1)].append(p)
        elif ext == ".import":
            for m in UID_IMPORT.finditer(read(p)):
                decl[m.group(1)].append(p)
        elif p.endswith(".uid"):
            u = read(p).strip()
            if u.startswith("uid://"):
                decl[u].append(p)
    return decl


def check_conflict_markers(files):
    for p in files:
        if not is_text(p):
            continue
        txt = read(p)
        if "<<<<<<<" not in txt and ">>>>>>>" not in txt:
            continue
        for i, line in enumerate(txt.splitlines(), 1):
            if line.startswith(("<<<<<<< ", ">>>>>>> ", "||||||| ")) or line.rstrip() == "=======":
                add("conflict-markers", ERROR, "merge conflict marker left in file", p, i, "Merge conflict marker")


def check_duplicate_uids(decl):
    for u, fs in decl.items():
        fs = sorted(set(fs))
        if len(fs) > 1:
            for f in fs:
                others = ", ".join(x for x in fs if x != f)
                add("duplicate-uid", ERROR, f"{u} also declared in: {others}", f, 1, "Duplicate UID")


def check_references(files, decl):
    declared = set(decl)
    for p in files:
        if os.path.splitext(p)[1].lower() not in (".tscn", ".tres"):
            continue
        for i, line in enumerate(read(p).splitlines(), 1):
            mu = EXT_UID.search(line)
            if mu and mu.group(1) not in declared:
                mp = RESPATH.search(line)
                path_ok = mp and os.path.exists(os.path.join(ROOT, mp.group(1)[6:]))
                if path_ok:
                    add("dangling-uid", WARN, f"{mu.group(1)} unknown; loads via path fallback but fragile", p, i, "Stale UID reference")
                else:
                    add("dangling-uid", ERROR, f"{mu.group(1)} unknown and no valid path — resource will fail to load", p, i, "Dangling UID")
            mp = RESPATH.search(line)
            if mp and not os.path.exists(os.path.join(ROOT, mp.group(1)[6:])):
                add("broken-path", ERROR, f"missing resource {mp.group(1)}", p, i, "Broken resource path")


def check_companions(files):
    fileset = set(files)
    for p in files:
        ext = os.path.splitext(p)[1].lower()
        if ext in IMPORTABLE and p + ".import" not in fileset:
            add("missing-companion", WARN, "asset has no .import sibling (won't load in export)", p, None, "Missing .import")
        if ext == ".import" and p[:-7] not in fileset:
            add("missing-companion", WARN, "orphan .import (source asset missing)", p, None, "Orphan .import")
        if ext == ".gd" and p + ".uid" not in fileset:
            add("missing-companion", NOTICE, "script has no .uid sibling", p, None, "Missing .uid")


def check_project_godot(decl):
    declared = set(decl)
    txt = read("project.godot")
    if not txt:
        return
    section, seen = None, collections.defaultdict(set)
    in_autoload = False
    for i, raw in enumerate(txt.splitlines(), 1):
        s = raw.strip()
        ms = re.match(r'^\[([^\]]+)\]$', s)
        if ms:
            section = ms.group(1)
            in_autoload = section == "autoload"
            continue
        mk = re.match(r'^([A-Za-z0-9_/.]+)\s*=', s)
        if mk and section:
            k = mk.group(1)
            if k in seen[section]:
                add("project-godot", WARN, f"duplicate key '{k}' in [{section}]", "project.godot", i, "Duplicate key")
            seen[section].add(k)
        if in_autoload and "=" in s and not s.startswith("["):
            ref = s.split("=", 1)[1].strip().strip('"').lstrip("*")
            if ref.startswith("uid://") and ref not in declared:
                add("project-godot", ERROR, f"autoload points at undeclared {ref}", "project.godot", i, "Broken autoload")
            elif ref.startswith("res://") and not os.path.exists(os.path.join(ROOT, ref[6:])):
                add("project-godot", ERROR, f"autoload points at missing {ref}", "project.godot", i, "Broken autoload")
    m = re.search(r'run/main_scene="([^"]+)"', txt)
    if m:
        ref = m.group(1)
        if ref.startswith("uid://") and ref not in declared:
            add("project-godot", ERROR, f"main_scene {ref} does not resolve — game won't boot", "project.godot", None, "Broken main scene")
        elif ref.startswith("res://") and not os.path.exists(os.path.join(ROOT, ref[6:])):
            add("project-godot", ERROR, "main_scene file missing — game won't boot", "project.godot", None, "Broken main scene")


def check_filenames(files):
    lower = collections.defaultdict(set)
    for p in files:
        lower[p.lower()].add(p)
        base = os.path.basename(p)
        if WIN_ILLEGAL.search(base):
            add("filename-hygiene", ERROR, "name has a Windows-illegal char (:*?\"<>|) — breaks clone on Windows", p, None, "Illegal filename")
        elif any(ord(c) > 127 for c in p):
            add("filename-hygiene", WARN, "path has non-ASCII characters — risky across toolchains", p, None, "Non-ASCII path")
    for paths in lower.values():
        if len(paths) > 1:
            add("filename-case", ERROR, "case-only collision: " + ", ".join(sorted(paths)) + " — breaks on case-insensitive filesystems", sorted(paths)[0], None, "Case collision")


def check_format_drift(files):
    fmts = collections.defaultdict(list)
    for p in files:
        if p.lower().endswith(".tscn"):
            m = SCENE_FMT.match(first_line(p))
            if m:
                fmts[m.group(1)].append(p)
    if len(fmts) > 1:
        majority = max(fmts, key=lambda k: len(fmts[k]))
        for fmt, paths in fmts.items():
            if fmt == majority:
                continue
            for p in paths:
                add("format-drift", NOTICE, f"scene format={fmt} differs from majority format={majority} (Godot version drift?)", p, 1, "Scene format drift")


def check_committed_cache(files):
    cache = [p for p in files if p.startswith(".godot/") or p.startswith(".import/")]
    if cache:
        add("committed-cache", WARN, f"{len(cache)} import-cache file(s) committed (e.g. {cache[0]}); add .godot/ to .gitignore", cache[0], None, "Committed cache")
    for p in files:
        b = os.path.basename(p)
        if b in (".DS_Store", "Thumbs.db", "desktop.ini") or p.endswith((".tmp", "~")):
            add("committed-cache", WARN, "OS/temp junk file committed", p, None, "Committed junk")


def emit():
    findings.sort(key=lambda f: (_RANK[f["sev"]], f["check"], f["file"] or ""))
    for f in findings:
        loc = ""
        if f["file"]:
            loc = "file=" + f["file"]
            if f["line"]:
                loc += ",line=" + str(f["line"])
            loc += ","
        title = f["title"].replace("\n", " ")
        msg = f["msg"].replace("\n", " ")
        print(f"::{f['sev']} {loc}title={title}::{msg}")

    counts = collections.Counter(f["sev"] for f in findings)
    icon = {ERROR: "🔴", WARN: "🟡", NOTICE: "🔵"}
    out = ["## 🧪 Godot health check\n",
           f"**{counts.get(ERROR, 0)} error · {counts.get(WARN, 0)} warning · "
           f"{counts.get(NOTICE, 0)} notice** — _informational, non-blocking._\n"]
    if not findings:
        out.append("✅ No issues found.\n")
    else:
        out += ["| Sev | Check | Where | Detail |", "|---|---|---|---|"]
        for f in findings[:200]:
            where = f["file"] or "—"
            if f["file"] and f["line"]:
                where += f":{f['line']}"
            out.append(f"| {icon[f['sev']]} | {f['check']} | `{where}` | {f['msg'].replace('|', chr(92) + '|')} |")
        if len(findings) > 200:
            out.append(f"\n_…and {len(findings) - 200} more_")
    report = "\n".join(out) + "\n"
    sp = os.environ.get("GITHUB_STEP_SUMMARY")
    if sp:
        with open(sp, "a") as fh:
            fh.write(report)
    print(report, file=sys.stderr)


def main():
    files = tracked_files()
    decl = build_uid_index(files)
    check_conflict_markers(files)
    check_duplicate_uids(decl)
    check_references(files, decl)
    check_companions(files)
    check_project_godot(decl)
    check_filenames(files)
    check_format_drift(files)
    check_committed_cache(files)
    emit()
    threshold = "warning" if "--strict" in sys.argv else "none"
    for a in sys.argv:
        if a.startswith("--fail-on="):
            threshold = a.split("=", 1)[1]
    fail_set = {"error": {ERROR}, "warning": {ERROR, WARN},
                "notice": {ERROR, WARN, NOTICE}, "none": set()}.get(threshold, set())
    if any(f["sev"] in fail_set for f in findings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

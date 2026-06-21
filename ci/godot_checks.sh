#!/usr/bin/env bash
set -uo pipefail

GODOT="${GODOT:-godot}"
FRAMES="${SMOKE_FRAMES:-300}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stderr}"
LOG="$(mktemp)"

ERR='SCRIPT ERROR|Parse Error|Failed to|Cannot open|Cannot instantiate|ERROR:|Condition "'
IGN='WARNING|deprecat|Unable to load|No DRI3|Vulkan|OpenGL|GLES|XDG_|pulseaudio|ALSA|fontconfig|Unrecognized UID'
fail=0

emit()    { printf '::%s title=%s::%s\n' "$1" "$2" "$3"; }
note()    { printf '%s\n' "$1" >>"$SUMMARY"; }
section() { printf '\n## 🎮 %s\n\n' "$1" >>"$SUMMARY"; }
run_log() { timeout 120 "$@" >"$LOG" 2>&1 || true; }
filt()    { grep -E "$ERR" "$LOG" 2>/dev/null | grep -Ev "$IGN" | sort -u; }

section "Godot"
note "\`$("$GODOT" --version 2>/dev/null || echo 'not runnable')\`"

timeout 120 "$GODOT" --headless --path . --import --quit >/dev/null 2>&1 || true

section "Import"
run_log "$GODOT" --headless --path . --import
imp="$(filt)"
if [ -n "$imp" ]; then
  fail=1
  note '```'; note "$imp"; note '```'
  while IFS= read -r l; do emit error "Import error" "$l"; done <<<"$imp"
else
  note "✅ resources import clean"
fi

section "Script parse"
run_log "$GODOT" --headless --path . --script res://ci/parse_check.gd
if grep -q 'PARSE_CHECK_DONE' "$LOG"; then
  pf="$(grep '^PARSE_FAIL ' "$LOG" | sed 's/^PARSE_FAIL //')"
  if [ -n "$pf" ]; then
    fail=1
    while IFS= read -r f; do
      emit error "Parse error" "$f"
      note "- 🔴 \`$f\`"
    done <<<"$pf"
  else
    note "✅ all scripts parse"
  fi
else
  fail=1
  note "⚠️ parse tool did not run to completion"
fi

section "Boot smoke test"
run_log "$GODOT" --headless --path . --quit-after "$FRAMES"
serr="$(filt)"
if [ -n "$serr" ]; then
  fail=1
  note '```'; note "$serr"; note '```'
  while IFS= read -r l; do emit error "Runtime error at boot" "$l"; done <<<"$serr"
else
  note "✅ main scene booted ${FRAMES} frames with no runtime errors"
fi

rm -f "$LOG" 2>/dev/null || true
exit "$fail"

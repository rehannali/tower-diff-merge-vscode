#!/usr/bin/env bash
set -euo pipefail

# ── Destinations ────────────────────────────────────────────────────────────
DEST="$HOME/Library/Application Support/com.fournova.Tower3/CompareTools"
SCRIPTS_DEST="$DEST/scripts"

# ── Safety: dry-run by default ───────────────────────────────────────────────
DRY_RUN=true
[[ "${1:-}" == "--run" ]] && DRY_RUN=false

if $DRY_RUN; then
  echo "⚠  Dry-run mode — nothing will be moved. Pass --run to execute."
  echo ""
fi

# ── Move helper ──────────────────────────────────────────────────────────────
move_file() {
  local src="$1"
  local dest_dir="$2"

  if [[ ! -f "$src" ]]; then
    echo "  ✗ missing:        $src" >&2
    return
  fi

  if [[ -e "$dest_dir/$(basename "$src")" ]]; then
    echo "  ⚠ already exists: $dest_dir/$(basename "$src") — skipped" >&2
    return
  fi

  if $DRY_RUN; then
    echo "  → [dry-run] $src  ➜  $dest_dir/"
  else
    mkdir -p "$dest_dir"
    mv "$src" "$dest_dir/"
    echo "  ✓ moved: $src  ➜  $dest_dir/"
  fi
}

# ── Plist patch helper ───────────────────────────────────────────────────────
patch_plist() {
  local plist="$1"

  if [[ ! -f "$plist" ]]; then
    echo "  ✗ missing: $plist" >&2
    return
  fi

  echo ""
  echo "── Patching plist script paths ── ($plist)"

  # Find all .sh references currently without scripts/ prefix
  local refs
  refs=$(grep -o '[^>]*\.sh' "$plist" | grep -v 'scripts/' || true)

  if [[ -z "$refs" ]]; then
    echo "  ℹ no .sh references found needing update — already patched or none present"
    return
  fi

  while IFS= read -r ref; do
    local updated="scripts/$ref"
    if $DRY_RUN; then
      echo "  → [dry-run] plist ref: \"$ref\"  ➜  \"$updated\""
    else
      sed -i '' "s|>$ref<|>$updated<|g" "$plist"
      echo "  ✓ patched: \"$ref\"  ➜  \"$updated\""
    fi
  done <<< "$refs"
}

# ── Shell scripts → scripts/ subfolder ──────────────────────────────────────
SELF="$(basename "$0")"

echo "── Shell scripts ── (*.sh → $SCRIPTS_DEST)"
shopt -s nullglob
sh_files=( *.sh )
if (( ${#sh_files[@]} == 0 )); then
  echo "  (none found)"
else
  for f in "${sh_files[@]}"; do
    if [[ "$f" == "$SELF" ]]; then
      echo "  ⊘ skipped self:   $f"
      continue
    fi
    move_file "$f" "$SCRIPTS_DEST"
  done
fi

# ── Patch plist before moving ────────────────────────────────────────────────
patch_plist "CompareTools.plist"

# ── Plist + other files → root CompareTools folder ──────────────────────────
echo ""
echo "── Other files ── (*.plist → $DEST)"
other_files=( *.plist )
if (( ${#other_files[@]} == 0 )); then
  echo "  (none found)"
else
  for f in "${other_files[@]}"; do
    move_file "$f" "$DEST"
  done
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo "Dry-run complete. Inspect the output above, then re-run with --run."
else
  echo "Done."
fi

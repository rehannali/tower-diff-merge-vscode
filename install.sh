#!/usr/bin/env bash
set -euo pipefail

# ── Destinations ─────────────────────────────────────────────────────────────
DEST="$HOME/Library/Application Support/com.fournova.Tower3/CompareTools"
SCRIPTS_DEST="$DEST/scripts"
SELF="$(basename "$0")"

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: bash $SELF [--run] <command> [target]

Commands:
  install               Copy all files to target (skips existing)
  replace               Overwrite all already-installed files
  replace <file>        Overwrite a single file (e.g. replace vscode.sh)
  remove                Remove all installed files from target
  remove <file>         Remove a single installed file

Flags:
  --run                 Execute for real (default is dry-run)

Examples:
  bash $SELF                          # dry-run install all
  bash $SELF --run install            # copy all files to target
  bash $SELF --run replace            # overwrite all
  bash $SELF --run replace vscode.sh  # overwrite one
  bash $SELF --run remove             # remove all from target
  bash $SELF --run remove vscode.sh   # remove one from target
EOF
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
DRY_RUN=true
COMMAND="install"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run)    DRY_RUN=false; shift ;;
    --help)   usage ;;
    install|replace|remove) COMMAND="$1"; shift
      [[ $# -gt 0 && "$1" != --* ]] && { TARGET="$1"; shift; } ;;
    *) echo "✗ Unknown argument: $1" >&2; usage ;;
  esac
done

if $DRY_RUN; then
  echo "⚠  Dry-run mode — nothing will change. Pass --run to execute."
  echo ""
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

dest_for() {
  local f="$1"
  [[ "$f" == *.sh ]] && echo "$SCRIPTS_DEST" || echo "$DEST"
}

do_copy() {
  local src="$1" dest_dir="$2"
  local dest="$dest_dir/$(basename "$src")"

  if [[ ! -f "$src" ]]; then
    echo "  ✗ missing source:  $src" >&2; return
  fi
  if [[ -e "$dest" ]]; then
    echo "  ⚠ already exists:  $dest — skipped (use replace)" >&2; return
  fi

  if $DRY_RUN; then
    echo "  → [dry-run] copy   $src  ➜  $dest_dir/"
  else
    mkdir -p "$dest_dir"
    cp "$src" "$dest_dir/"
    echo "  ✓ copied:          $src  ➜  $dest_dir/"
  fi
}

do_replace() {
  local src="$1" dest_dir="$2"
  local dest="$dest_dir/$(basename "$src")"

  if [[ ! -f "$src" ]]; then
    echo "  ✗ missing source:  $src" >&2; return
  fi

  if $DRY_RUN; then
    local status="new"
    [[ -e "$dest" ]] && status="overwrite"
    echo "  → [dry-run] replace ($status)  $src  ➜  $dest_dir/"
  else
    mkdir -p "$dest_dir"
    cp "$src" "$dest_dir/"
    echo "  ✓ replaced:        $src  ➜  $dest_dir/"
  fi
}

do_remove() {
  local target_file="$1" dest_dir="$2"
  local dest="$dest_dir/$(basename "$target_file")"

  if [[ ! -e "$dest" ]]; then
    echo "  ⚠ not installed:   $dest — skipped" >&2; return
  fi

  if $DRY_RUN; then
    echo "  → [dry-run] remove $dest"
  else
    rm "$dest"
    echo "  ✓ removed:         $dest"
  fi
}

# ── Plist patch ───────────────────────────────────────────────────────────────
patch_plist() {
  local plist="$1"
  [[ ! -f "$plist" ]] && { echo "  ✗ missing: $plist" >&2; return; }

  echo ""
  echo "── Patching plist script paths ── ($plist)"

  local refs
  refs=$(grep -o '[^>]*\.sh' "$plist" | grep -v 'scripts/' || true)

  if [[ -z "$refs" ]]; then
    echo "  ℹ paths already up to date — no changes needed"
    return
  fi

  while IFS= read -r ref; do
    if $DRY_RUN; then
      echo "  → [dry-run] \"$ref\"  ➜  \"scripts/$ref\""
    else
      sed -i '' "s|>$ref<|>scripts/$ref<|g" "$plist"
      echo "  ✓ patched: \"$ref\"  ➜  \"scripts/$ref\""
    fi
  done <<< "$refs"
}

# ── Collect managed files ─────────────────────────────────────────────────────
shopt -s nullglob
all_sh=( *.sh )
all_other=( *.plist )

managed_sh=()
for f in "${all_sh[@]}"; do
  [[ "$f" == "$SELF" ]] && { echo "  ⊘ skipped self:    $f"; continue; }
  managed_sh+=("$f")
done

# ── Command dispatch ──────────────────────────────────────────────────────────
case "$COMMAND" in

  install)
    echo "── Installing all files ─────────────────────────────────────────────"
    [[ ${#managed_sh[@]} -gt 0 ]] && {
      echo "   Scripts → $SCRIPTS_DEST"
      for f in "${managed_sh[@]}"; do do_copy "$f" "$SCRIPTS_DEST"; done
    }
    patch_plist "CompareTools.plist"
    echo ""
    echo "   Other → $DEST"
    for f in "${all_other[@]}"; do do_copy "$f" "$DEST"; done
    ;;

  replace)
    if [[ -n "$TARGET" ]]; then
      echo "── Replacing single file: $TARGET ──────────────────────────────────"
      do_replace "$TARGET" "$(dest_for "$TARGET")"
      [[ "$TARGET" == *.plist ]] && patch_plist "$TARGET"
    else
      echo "── Replacing all files ──────────────────────────────────────────────"
      [[ ${#managed_sh[@]} -gt 0 ]] && {
        echo "   Scripts → $SCRIPTS_DEST"
        for f in "${managed_sh[@]}"; do do_replace "$f" "$SCRIPTS_DEST"; done
      }
      patch_plist "CompareTools.plist"
      echo ""
      echo "   Other → $DEST"
      for f in "${all_other[@]}"; do do_replace "$f" "$DEST"; done
    fi
    ;;

  remove)
    if [[ -n "$TARGET" ]]; then
      echo "── Removing single file: $TARGET ───────────────────────────────────"
      do_remove "$TARGET" "$(dest_for "$TARGET")"
    else
      echo "── Removing all installed files ─────────────────────────────────────"
      echo "   From $SCRIPTS_DEST"
      for f in "${managed_sh[@]}"; do do_remove "$f" "$SCRIPTS_DEST"; done
      echo ""
      echo "   From $DEST"
      for f in "${all_other[@]}"; do do_remove "$f" "$DEST"; done
    fi
    ;;

esac

echo ""
$DRY_RUN && echo "Dry-run complete. Inspect above, then re-run with --run." || echo "Done."

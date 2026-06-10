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
  install               Move all files to target (default, skips existing)
  replace               Overwrite all already-installed files
  replace <file>        Overwrite a single file (e.g. replace vscode.sh)
  remove                Remove all installed files from target
  remove <file>         Remove a single installed file

Flags:
  --run                 Execute for real (default is dry-run)

Examples:
  bash $SELF                          # dry-run install all
  bash $SELF --run install            # install all
  bash $SELF --run replace            # replace all
  bash $SELF --run replace vscode.sh  # replace one
  bash $SELF --run remove             # remove all
  bash $SELF --run remove vscode.sh   # remove one
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

# Resolve which destination dir a source file belongs to
dest_for() {
  local f="$1"
  [[ "$f" == *.sh ]] && echo "$SCRIPTS_DEST" || echo "$DEST"
}

do_move() {
  local src="$1" dest_dir="$2"
  local dest="$dest_dir/$(basename "$src")"

  if [[ ! -f "$src" ]]; then
    echo "  ✗ missing source:  $src" >&2; return
  fi
  if [[ -e "$dest" ]]; then
    echo "  ⚠ already exists:  $dest — skipped (use replace)" >&2; return
  fi

  if $DRY_RUN; then
    echo "  → [dry-run] move   $src  ➜  $dest_dir/"
  else
    mkdir -p "$dest_dir"
    mv "$src" "$dest_dir/"
    echo "  ✓ moved:           $src  ➜  $dest_dir/"
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
    mv "$src" "$dest_dir/"
    echo "  ✓ replaced:        $src  ➜  $dest_dir/"
  fi
}

do_remove() {
  local target_file="$1"
  local dest_dir="$2"
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

# ── Collect all managed files ─────────────────────────────────────────────────
shopt -s nullglob
all_sh=( *.sh )
all_other=( *.plist )

# Remove self from .sh list
managed_sh=()
for f in "${all_sh[@]}"; do
  [[ "$f" == "$SELF" ]] && { echo "  ⊘ skipped self:    $f"; continue; }
  managed_sh+=("$f")
done

all_files=( "${managed_sh[@]}" "${all_other[@]}" )

# ── Command dispatch ──────────────────────────────────────────────────────────
case "$COMMAND" in

  # ── Install ────────────────────────────────────────────────────────────────
  install)
    echo "── Installing all files ─────────────────────────────────────────────"
    [[ ${#managed_sh[@]} -gt 0 ]] && {
      echo "   Scripts → $SCRIPTS_DEST"
      for f in "${managed_sh[@]}"; do do_move "$f" "$SCRIPTS_DEST"; done
    }
    patch_plist "CompareTools.plist"
    echo ""
    echo "   Other → $DEST"
    for f in "${all_other[@]}"; do do_move "$f" "$DEST"; done
    ;;

  # ── Replace ────────────────────────────────────────────────────────────────
  replace)
    if [[ -n "$TARGET" ]]; then
      # Single file
      echo "── Replacing single file: $TARGET ──────────────────────────────────"
      dest_dir="$(dest_for "$TARGET")"
      do_replace "$TARGET" "$dest_dir"
      [[ "$TARGET" == *.plist ]] && patch_plist "$TARGET"
    else
      # All files
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

  # ── Remove ─────────────────────────────────────────────────────────────────
  remove)
    if [[ -n "$TARGET" ]]; then
      # Single file
      echo "── Removing single file: $TARGET ───────────────────────────────────"
      dest_dir="$(dest_for "$TARGET")"
      do_remove "$TARGET" "$dest_dir"
    else
      # All files
      echo "── Removing all installed files ─────────────────────────────────────"
      echo "   From $SCRIPTS_DEST"
      for f in "${managed_sh[@]}"; do do_remove "$f" "$SCRIPTS_DEST"; done
      echo ""
      echo "   From $DEST"
      for f in "${all_other[@]}"; do do_remove "$f" "$DEST"; done
    fi
    ;;

esac

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo "Dry-run complete. Inspect above, then re-run with --run."
else
  echo "Done."
fi

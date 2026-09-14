#!/usr/bin/env bash

# Shared Tower launcher for VS Code-family applications.  Keep this file next
# to the small editor-specific wrappers so they can source it after Tower copies
# the scripts into its CompareTools directory.

find_app_by_bundle_identifier() {
  local bundle_identifier="$1"
  local app_path
  local found_identifier

  # Spotlight searches every indexed location, including ~/Applications.  Do
  # not assume that the application lives in /Applications.
  while IFS= read -r app_path; do
    [[ "$app_path" == *.app && -d "$app_path" ]] || continue

    found_identifier=$(
      /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
        "$app_path/Contents/Info.plist" 2>/dev/null
    ) || continue

    [[ "$found_identifier" == "$bundle_identifier" ]] || continue
    printf '%s\n' "$app_path"
    return 0
  done < <(
    /usr/bin/mdfind "kMDItemCFBundleIdentifier == '$bundle_identifier'" 2>/dev/null
  )

  return 1
}

resolve_editor_command() {
  local bundle_identifier="$1"
  local command_name="$2"
  local app_path
  local embedded_command

  if app_path=$(find_app_by_bundle_identifier "$bundle_identifier"); then
    embedded_command="$app_path/Contents/Resources/app/bin/$command_name"
    if [[ -x "$embedded_command" ]]; then
      printf '%s\n' "$embedded_command"
      return 0
    fi

    printf 'Found application bundle at %s, but its embedded %s launcher is unavailable.\n' \
      "$app_path" "$command_name" >&2
    return 1
  fi

  # PATH is only a fallback when no matching application bundle can be found.
  command -v "$command_name"
}

absolute_path() {
  local path="$1"

  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$PWD" "${path#./}" ;;
  esac
}

tower_vscode_launch() {
  local bundle_identifier="$1"
  local command_name="$2"
  local application_name="$3"
  local local_path="${4-}"
  local remote_path="${5-}"
  local merge_path="${7-}"
  local command
  local backup

  if [[ -z "$local_path" || -z "$remote_path" ]]; then
    printf '%s requires local and remote file paths.\n' "$application_name" >&2
    return 128
  fi

  local_path=$(absolute_path "$local_path")
  remote_path=$(absolute_path "$remote_path")

  if ! command=$(resolve_editor_command "$bundle_identifier" "$command_name"); then
    printf '%s could not be found. Expected bundle identifier %s, or %s on PATH.\n' \
      "$application_name" "$bundle_identifier" "$command_name" >&2
    return 128
  fi

  if [[ -n "$merge_path" ]]; then
    merge_path=$(absolute_path "$merge_path")

    if [[ ! -f "$merge_path" ]]; then
      # For conflict "Both Added", Git does not pass the merge parameter
      # correctly in current versions.
      merge_path=$(sed -E 's/\.LOCAL\.[0-9]*//' <<<"$local_path")
    fi

    backup=$(mktemp "${TMPDIR:-/tmp}/tower-vscode.XXXXXX") || return 1
    trap 'rm -f "$backup"' RETURN
    sleep 1 # Ensure the marker predates an editor write on coarse file systems.
    touch "$backup"

    "$command" --new-window --wait "$merge_path"

    if [[ "$merge_path" -ot "$backup" ]]; then
      return 1
    fi
    return 0
  fi

  "$command" --new-window --wait --diff "$local_path" "$remote_path"
}

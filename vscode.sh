#!/usr/bin/env bash

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=vscode-common.sh
source "$script_dir/vscode-common.sh"

tower_vscode_launch "com.microsoft.VSCode" "code" "Visual Studio Code" "$@"

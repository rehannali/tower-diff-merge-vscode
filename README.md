# Use VS Code-family editors as Merge and Diff tools in Tower Git GUI (macOS)

## Screenshots

---

![Tower Merge](/screenshots/tower_merge.png)

![Tower Merge](/screenshots/vscode_merge.png)

![Tower Merge](/screenshots/vscode_diff.png)

## Installation

---

```bash
$ git clone https://github.com/rehannali/tower-diff-merge-vscode.git
$ cd tower-diff-merge-vscode
# Preview first (safe, nothing moves)
$ bash install.sh

# Execute once you're happy
$ bash install.sh --run

# For Help and see other menus
$ bash install.sh --help
Usage: bash install.sh [--run] <command> [target]

# Upgrade an existing installation (also updates the shared launcher helper)
$ bash install.sh --run replace
```

-   Then restart Tower3 app
-   Go to Preferences -> Git Config
-   Select **Visual Studio Code (Custom Integration)**, **Visual Studio Code
    Insiders (Custom Integration)**, or **VSCodium (Custom Integration)** for
    both Diff Tool and Merge Tool. These names intentionally differ from
    Tower's built-in entries, making it clear that you selected this project's
    integration. The integration resolves the matching app by its macOS bundle
    identifier, so it also supports `~/Applications` and other
    Spotlight-indexed locations.
    ![Tower Setup](/screenshots/tower_setup.png)

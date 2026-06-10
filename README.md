# Use Visual Studio Code as Merge and Diff tool in Tower Git GUI (MacOs)

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
```

-   Then restart Tower3 app
-   Go to Preferences -> Git Config
-   Select 'Visual Studio Code' for both Diff tool and Merge tool
    ![Tower Setup](/screenshots/tower_setup.png)

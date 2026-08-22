---
name: repo-map
description: Use when locating a registered or related local repository, or when discovering commands registered through repo-map. Do not use for source-tree, symbol, or architecture mapping.
---

# repo-map

Follow project instructions before this Skill.

Use `repo-map` when the requested local repository or helper command is not
already identified by the project. Prefer targeted lookups:

- `repo-map get NAME` for a known repository
- `repo-map command NAME` for a known helper
- `repo-map commands` only when the needed registered command is unknown

If `repo-map` is available, use it instead of a broad filesystem search. If it
is unavailable, use the current workspace or ask the user for the repository
location. Do not download or install Agent Scripts automatically.

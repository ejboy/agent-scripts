---
name: repolink
description: Use when locating a registered or related local repository, or when discovering commands registered through RepoLink. Do not use for source-tree, symbol, or architecture mapping.
---

# RepoLink

Follow project instructions before this Skill.

Use RepoLink when the requested local repository or helper command is not
already identified by the project. Prefer targeted lookups:

- `repolink get NAME` for a known repository
- `repolink command NAME` for a known helper
- `repolink commands` only when the needed registered command is unknown

If `repolink` is available, use it instead of a broad filesystem search. If it
is unavailable, use the current workspace or ask the user for the repository
location. Do not download or install Agent Scripts automatically.

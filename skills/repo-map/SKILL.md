---
name: repo-map
description: Compatibility skill for existing RepoMap instructions. RepoLink and repolink are canonical for new usage.
---

# RepoMap compatibility

This skill remains available for existing agent configurations. RepoLink is the
current tool name and `repolink` is its canonical command. Follow project
instructions before using it.

Use `repolink` for targeted lookups:

- `repolink get NAME` for a known repository
- `repolink command NAME` for a known helper
- `repolink commands` only when the needed registered command is unknown

If `repolink` is unavailable, use the current workspace or ask the user for the
repository location. Do not download or install Agent Scripts automatically.

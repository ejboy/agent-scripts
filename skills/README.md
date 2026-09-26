# Agent Skills

Agent Scripts provides two current Agent Skills for coding-agent workflows:

- [`repolink`](repolink/SKILL.md) for targeted repository and local-tool discovery.
- [`lite-tools`](lite-tools/SKILL.md) for more introverted Maven, npm/Node, and Go test workflows that reduce noisy output and token/context usage.

Install both globally with the Skills CLI:

```bash
npx skills add ejboy/agent-scripts --global --skill repolink --skill lite-tools
```

The deprecated [`repo-map` compatibility Skill](repo-map/SKILL.md) remains
available for existing agent configurations and directs agents to `repolink`.

Skills are separate from the distributable command-line tools. See the [main
repository README](../README.md) for command installation and PATH setup.

Node.js/npm is needed only for `npx skills`. The repository installer installs
commands only and does not invoke the Skills CLI.

> [!NOTE]
> Claude Code loads personal Skills from `~/.claude/skills/`. The generic
> `--global` command above targets it when Claude Code is auto-detected. If it
> is not detected, add `--agent claude-code` to target it explicitly. Restart
> Claude Code only if `~/.claude/skills/` is created during an active session.

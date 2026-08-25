# Agent Skills

Agent Scripts currently provides two Agent Skills for coding-agent workflows:

- [`repo-map`](repo-map/SKILL.md) for targeted repository and local-tool discovery.
- [`lite-tools`](lite-tools/SKILL.md) for more introverted Maven, npm/Node, and Go test workflows that reduce noisy output and token/context usage.

Install both globally with the Skills CLI:

```bash
npx skills add https://github.com/ejboy/agent-scripts --global --skill repo-map --skill lite-tools
```

Skills are separate from the distributable command-line tools. See the [main
repository README](../README.md) for command installation and PATH setup.

Node.js/npm is needed only for `npx skills`. The repository installer installs
commands only and does not invoke the Skills CLI.

## Claude Code

Claude Code loads personal Skills from `~/.claude/skills/`, not from other
agents' global Skill directories. If Claude Code is not auto-detected, target
it explicitly:

```bash
npx skills add https://github.com/ejboy/agent-scripts --global --agent claude-code --skill repo-map --skill lite-tools
```

Restart Claude Code if `~/.claude/skills/` is created during an active session.

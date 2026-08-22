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

# Agent Skills

Agent Scripts provides these Agent Skills:

- [`repolink`](repolink/SKILL.md) for targeted repository and local-tool discovery.
- [`lite-tools`](lite-tools/SKILL.md) for more introverted Maven, npm/Node, and Go test workflows that reduce noisy output and token/context usage.
- [`lightweight-monitoring`](lightweight-monitoring/SKILL.md) (experimental) for minimal application monitoring, reusing framework facilities and integrating StatLite when appropriate.
- [`coilbase-spring-migration`](coilbase-spring-migration/SKILL.md) (experimental) for bounded Spring Boot JDBC migration guidance and identifying features requiring explicit application decisions.
- [`coilbase-jpa-migration`](coilbase-jpa-migration/SKILL.md) (experimental) for JPA and Hibernate migrations to CoilBase

Install the two utility skills globally with the Skills CLI:

```bash
npx skills add ejboy/agent-scripts --global --skill repolink --skill lite-tools
```

Install the monitoring skill separately:

```bash
npx skills add ejboy/agent-scripts --global --skill lightweight-monitoring
```

Choose the CoilBase skill that fits the workflow. Use the Spring migration
skill for Spring Boot workflows that already use JDBC. Use the JPA migration
skill for workflows that rely on JPA, Spring Data JPA, or Hibernate, whether
you plan to replace the ORM with explicit SQL or retain Hibernate. Each skill
can be installed and used independently.

```bash
npx skills add ejboy/agent-scripts --global --skill coilbase-spring-migration
```

```bash
npx skills add ejboy/agent-scripts --global --skill coilbase-jpa-migration
```

Try asking: "Add lightweight monitoring to this application." The skill checks
the framework, existing instrumentation, and deployment model, then preserves
suitable monitoring or implements a minimal StatLite integration when one fits.
It covers Spring Boot, Quarkus, FastAPI, Django, Express, and Go through canonical
integration guides. Application-owned StatLite helpers support one process or
worker. The skill does not require the Agent Scripts commands.

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

---
name: lite-tools
description: Make Maven, npm/Node, and Go test workflows more introverted with compact build/test output that reduces noisy output and token or context usage for coding agents.
---

# lite-tools

Follow project instructions before this Skill.

For supported workflows, prefer the corresponding compact wrapper:

- Maven: prefer `mvn-lite` for supported build and test workflows.
- npm / Node tests: prefer `npm-lite` for `npm run verify`, `npm run test:unit`,
  and supported `node --test` workflows.
- Go tests: prefer `go-lite` for `go test`.

Use normal `npm` or `node` when npm-lite is unavailable or the workflow is
unsupported. For a test workflow where go-lite is unavailable, use `go test`;
for non-test Go workflows, use the normal `go` command. For Maven, fall back
to executable `./mvnw` when present, otherwise `mvn`. Do not claim compact
behavior for unsupported npm or Go commands. Use `mvn-lite --full` only when
compact Maven output is insufficient for diagnosis. Do not download or install
Agent Scripts automatically.

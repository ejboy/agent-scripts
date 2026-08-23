---
name: lite-tools
description: Use compact wrappers when running routine Maven builds and tests, supported npm/Node test workflows, or Go tests. Select mvn-lite for supported Maven build and test workflows, npm-lite for npm run verify, npm run test:unit, or node --test, and go-lite for go test.
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

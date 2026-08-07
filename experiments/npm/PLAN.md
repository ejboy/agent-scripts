# npm-lite Plan

Status: Active
Created: 2026-08-07

## Goal

Reduce agent-visible output from successful `npm run verify` and
`npm run test:unit` executions while preserving npm behavior, useful failure
details, and access to the complete output.

## Scope

Compact mode applies only to these exact argument sequences:

```text
npm-lite run verify
npm-lite run test:unit
```

All other arguments execute as:

```text
npm "$@"
```

Invocations with additional arguments are initially pass-through. Examples
include `npm-lite run verify -- --foo`, `npm-lite test`, and npm informational
flags.

## Proposed behavior

- Run npm in the caller's working directory.
- Preserve npm's exit status and interrupt behavior.
- Capture complete compact-mode output under `.agent-logs/npm/`.
- On success, print one line with status, duration, and a test count when one can
  be extracted conservatively.
- Delete successful logs by default.
- On failure, print a bounded summary and retain the complete log.
- If no useful failure can be recognized, print a bounded tail and the retained
  log path.
- Do not modify package files or inject reporter arguments into project scripts.

## Implementation sequence

1. [x] Add a shell wrapper and deterministic fake-npm test fixture.
2. [x] Test exact command recognition, pass-through arguments, exit statuses,
   successful summaries, failure summaries, fallback tails, and log retention.
3. [ ] Run against the local workflows represented in
   [LOCAL-OBSERVATIONS.md](LOCAL-OBSERVATIONS.md).
4. [ ] Compare visible bytes or tokens before and after, then decide whether the
   experiment should graduate into `scripts/`.

## Exit criteria

- Unsupported invocations are observably identical to direct npm invocation.
- Both supported successful workflows produce compact output.
- Failures remain actionable without streaming every passing test.
- Raw failed output is retained and easy to locate.
- Local measurements demonstrate meaningful output reduction.

## Non-goals

- General npm output parsing.
- Supporting arbitrary package scripts in compact mode.
- Changing test reporters or package configuration.
- Improving execution time.
- Replacing npm, a task runner, or CI output.

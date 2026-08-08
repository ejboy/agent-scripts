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
3. [x] Handle log-directory and temporary-file setup failures without invoking
   npm, clean up partial files, preserve pass-through streams and statuses, and
   verify exact argument boundaries.
4. [ ] Run against the local workflows represented in
   [LOCAL-OBSERVATIONS.md](LOCAL-OBSERVATIONS.md).
5. [ ] Compare visible bytes or tokens before and after, then decide whether the
   experiment should graduate into `scripts/`.

## Production graduation checklist

### Public contract

- [ ] Decide whether the two exact supported script names are intentionally the
  complete public scope or whether other scripts can explicitly opt into compact
  mode.
- [ ] Keep successful output visible for commands outside the documented compact
  scope.
- [ ] Add wrapper help and version output.
- [ ] Add `--full` and `--raw` controls for ordinary live npm output.
- [ ] Add `--keep-log` and consider a log-directory override.
- [ ] Define a `--` boundary between wrapper options and npm arguments.

### Privacy and pass-through behavior

- [ ] Remove experiment instrumentation before graduation, as promised in the
  experiment README, or make collection explicitly opt-in.
- [ ] After removing instrumentation, use `exec npm "$@"` for unsupported
  invocations so npm directly owns pass-through input, output, signals, and exit
  status.
- [ ] Verify informational commands and representative unsupported commands are
  observably equivalent to direct npm invocations.

### Process behavior

- [ ] Forward `INT` and `TERM` to the npm child and return conventional interrupt
  statuses.
- [ ] Ensure terminating the wrapper does not leave npm or its descendants
  running.
- [ ] Decide and document whether compact workflows receive `/dev/null` or the
  caller's stdin; test the decision under a PTY.
- [ ] Retain the complete raw log after an interrupted compact run.

### Summaries and logs

- [ ] Validate failures from the real supported workflows and extract only
  stable, actionable failure details.
- [ ] Fall back to a tail bounded by both lines and bytes when no useful failure
  can be recognized.
- [ ] Always show the authoritative failed-log path and guidance for rerunning
  with full output.
- [ ] Test private log permissions under a permissive caller umask.
- [ ] Define failed-log retention and pruning so logs do not accumulate forever.
- [ ] Use recognizable log filenames and document that projects should ignore
  `.agent-logs/`.
- [ ] Test cleanup failures while preserving npm's exit status.

### Real-world validation

- [x] Measure one real successful `npm run verify`: visible output fell from
  18,861 bytes and 375 lines to 26 bytes and one line.
- [ ] Measure a real successful `npm run test:unit`.
- [ ] Exercise at least one controlled real failure for each supported workflow.
- [ ] Test npm missing from `PATH`, a project path containing spaces, and
  representative npm versions on macOS and Linux.
- [ ] Confirm successful summaries do not suppress information needed for the
  next action in the validated workflows.

### Repository integration

- [ ] Move the executable to `scripts/` and its tests and fixture to `tests/`.
- [ ] Adopt the shared release version constant and public-script provenance
  header.
- [ ] Add npm-lite to `tests/test-versions.sh` and `maintainers/bump-version`.
- [ ] Document installation, scope, wrapper options, logs, and examples in the
  repository README and installation guide.
- [ ] Run the complete `./tests/test-*.sh` suite and the repository's required
  ShellCheck command after moving public files.

## Exit criteria

- Unsupported invocations are observably identical to direct npm invocation.
- Both supported successful workflows produce compact output.
- Failures remain actionable without streaming every passing test.
- Raw failed output is retained and easy to locate.
- Interrupts stop the npm child, return a conventional status, and retain useful
  diagnostics.
- Logs are private, have a documented lifecycle, and do not accumulate without
  a retention policy.
- Local measurements demonstrate meaningful output reduction.
- Experiment-only instrumentation is absent from the public script unless users
  explicitly opt into it.
- The public script participates in repository versioning, documentation, static
  checks, and the full test suite.

## Non-goals

- General npm output parsing.
- Supporting arbitrary package scripts in compact mode.
- Changing test reporters or package configuration.
- Improving execution time.
- Replacing npm, a task runner, or CI output.

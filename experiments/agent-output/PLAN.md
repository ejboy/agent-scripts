# Agent-Friendly Tooling Plan

Status: Historical after `npm-lite` graduation; `agent-complaint` remains experimental.
Created: 2026-08-07
Expanded: 2026-08-08

## Goal

Develop a small, evidence-driven set of utilities that reduce agent-visible
tool output without hiding actionable failures or replacing project-specific
build and verification policy.

`npm-lite` was the implementation track and graduated to `scripts/npm-lite`.
Other candidates remain investigations until local observations and
measurements justify a public utility.

## Evidence

The local observations in
[LOCAL-OBSERVATIONS.md](LOCAL-OBSERVATIONS.md) recorded approximately 104,700
visible output tokens and 197 KB across five workspaces. The largest recurring
sources were broad searches and source dumps, npm verification output, and
verbose test or validation commands.

One real `npm run verify` measurement fell from 18,861 bytes and 375 lines to
26 bytes and one line through the experimental wrapper. Repository analysis
also found repeated verbose Go test entrypoints, direct Node test workflows,
browser diagnostics on successful screenshots, and overly broad process
inspection.

These observations are opportunistic rather than a controlled benchmark. Each
new utility must therefore be validated against real workflows before it joins
the public `scripts/` interface.

## Boundaries

- Keep tools deterministic, local-first, and close to the wrapped command's
  vocabulary.
- Prefer language- or tool-specific behavior with reliable failure parsing over
  a generic command-output wrapper.
- Preserve exit status, interrupt behavior, and access to authoritative raw
  diagnostics.
- Bound fallback output by both lines and bytes and report truncation
  explicitly.
- Keep module selection, test tiers, ports, services, and verification policy
  in application repositories.
- Do not build a generic `run-lite` utility.
- Do not invest in Ant support; Ant is deprecated in the relevant workspace.
- Defer a Pytest wrapper until repeated evidence shows that `pytest -q` is
  insufficient.
- Do not duplicate AI Badger's repository-topology and review-context roles or
  Projctl's multi-repository status role.

## Roadmap

### Track 1: Graduate `npm-lite`

Finish the current experiment and decide whether it is ready to become a public
script. This is the only active implementation track.

### Track 2: Investigate bounded search and source context

Working name: `rg-context`.

The experiment should test whether one focused command can replace the common
failure pattern of a broad `rg` invocation followed by oversized multi-file
`sed` output.

- [ ] Define a narrow command vocabulary for a pattern and explicit search
  paths.
- [ ] Honor Git ignore rules and exclude common generated, minified, lock, map,
  and binary files by default without silently excluding test fixtures.
- [ ] Coalesce overlapping context windows and cap output by lines and bytes.
- [ ] Report matching-file counts, omitted matches, and truncation explicitly.
- [ ] Provide an explicit full-output mode.
- [ ] Replay representative broad-search observations and compare visible
  output with the focused follow-up commands that proved useful.
- [ ] Decide whether one search-and-context tool is clearer than separate
  search-summary and source-window utilities.

### Track 3: Investigate language-specific test output

#### Go

Working name: `go-test-lite`.

Normal non-verbose `go test` output is already compact, so first determine
whether project-local removal of unnecessary `-v` flags solves the observed
problem. A public wrapper must provide additional value beyond that change.

Focused successful-package measurements on 2026-08-08 used `-count=1` in both
modes so the test-result cache could not skip execution:

| Package | Normal output | Verbose output | Reduction from removing `-v` |
| --- | ---: | ---: | ---: |
| AIBadger `internal/scanner` | 57 bytes, 1 line | 21,054 bytes, 330 lines | 99.7% bytes, 99.7% lines |
| StatLite `internal/config` | 56 bytes, 1 line | 3,319 bytes, 60 lines | 98.3% bytes, 98.3% lines |

The source trees contain approximately 734 AIBadger Go test functions and 167
StatLite Go test functions, and both project build scripts currently use
verbose Go tests. Full-suite verbose output was not generated because the
focused measurements were sufficient to establish the successful-output
pattern without initiating broader test suites solely for profiling.

These results show that a Go-aware compact path can remove nearly all verbose
successful output. They also show that ordinary `go test` already captures
nearly the entire saving: a dedicated wrapper could reduce only the remaining
56-57 successful bytes unless it deliberately adds a compact test/package
count. The wrapper therefore needs to demonstrate better structured failure
summaries or another material benefit before graduation.

- [x] Measure representative focused `go test` and `go test -v` successes in the
  Go workspaces.
- [ ] Measure full-workspace output only when a normal task already requires the
  suite or the user approves profiling it; do not run broad suites solely to
  improve the estimate.
- [ ] Compare project-local non-verbose defaults with a structured
  `go test -json` summarizer.
- [ ] If a wrapper remains justified, report package and test totals on success
  and actionable failed packages, tests, and output on failure.
- [ ] Preserve raw logs and conventional Go arguments, exit statuses, caching,
  and interrupt behavior.
- [ ] Do not graduate the experiment if removing `-v` provides substantially
  the same benefit on both successful and failed runs.

#### Node test runner

Working name: `node-test-lite`.

This track covers direct `node --test` workflows only. npm-owned verification
scripts remain under `npm-lite`.

- [ ] Measure direct Node test output in the current workspaces.
- [ ] Evaluate the compact-success and detailed-failure approach already used
  by Finrecord's project-local JavaScript test wrapper.
- [ ] Avoid rerunning failed suites when that could mask flaky behavior; prefer
  a reporter or captured output that retains the original failure evidence.
- [ ] Prototype only if the incremental value extends beyond one project-local
  wrapper.

### Track 4: Improve browser utilities

- [ ] Make successful non-verbose `html-screenshot` runs suppress harmless
  Chrome stderr after validating that the screenshot exists; retain diagnostics
  for failures and `--verbose`.
- [ ] Consider an explicit temporary-output option for sandboxed agent runs.
- [ ] Add `launch-browser --status` only if it can reuse existing owned state and
  report a compact PID, service, DevTools, and URL summary.
- [ ] Defer a VS Code development-host status utility until another observation
  confirms that the existing process-inspection complaint is recurring.

### Track 5: Evaluate `agent-complaint` graduation

- [ ] Continue collecting concise local observations without source, secrets,
  sensitive paths, or captured command output.
- [ ] Decide whether the collector should graduate independently of
  `npm-lite`.
- [ ] Consider a read-only summary command that groups complaints by command
  family and totals recorded lines and bytes without exposing detailed local
  context.

## Recommended sequence

1. Complete and validate `npm-lite` production graduation.
2. Decide whether `agent-complaint` should graduate so later decisions continue
   to use comparable evidence.
3. Prototype and measure `rg-context`, which has the broadest cross-project
   potential.
4. Measure project-local Go and Node improvements before implementing public
   language-specific wrappers.
5. Make small browser utility improvements when their existing behavior is
   already under test.

Only one implementation track should be active at a time unless the work is
independent and explicitly approved.

## Track 1 detail: `npm-lite`

### Goal

Reduce agent-visible output from successful `npm run verify` and
`npm run test:unit` executions while preserving npm behavior, useful failure
details, and access to the complete output.

### Scope

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

### Proposed behavior

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

### Implementation sequence

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

### Production graduation checklist

#### Public contract

- [ ] Decide whether the two exact supported script names are intentionally the
  complete public scope or whether other scripts can explicitly opt into compact
  mode.
- [ ] Keep successful output visible for commands outside the documented compact
  scope.
- [ ] Add wrapper help and version output.
- [ ] Add `--full` and `--raw` controls for ordinary live npm output.
- [ ] Add `--keep-log` and consider a log-directory override.
- [ ] Define a `--` boundary between wrapper options and npm arguments.

#### Privacy and pass-through behavior

- [ ] Remove experiment instrumentation before graduation, as promised in the
  experiment README, or make collection explicitly opt-in.
- [ ] After removing instrumentation, use `exec npm "$@"` for unsupported
  invocations so npm directly owns pass-through input, output, signals, and exit
  status.
- [ ] Verify informational commands and representative unsupported commands are
  observably equivalent to direct npm invocations.

#### Process behavior

- [ ] Forward `INT` and `TERM` to the npm child and return conventional interrupt
  statuses.
- [ ] Ensure terminating the wrapper does not leave npm or its descendants
  running.
- [ ] Decide and document whether compact workflows receive `/dev/null` or the
  caller's stdin; test the decision under a PTY.
- [ ] Retain the complete raw log after an interrupted compact run.

#### Summaries and logs

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

#### Real-world validation

- [x] Measure one real successful `npm run verify`: visible output fell from
  18,861 bytes and 375 lines to 26 bytes and one line.
- [ ] Measure a real successful `npm run test:unit`.
- [ ] Exercise at least one controlled real failure for each supported workflow.
- [ ] Test npm missing from `PATH`, a project path containing spaces, and
  representative npm versions on macOS and Linux.
- [ ] Confirm successful summaries do not suppress information needed for the
  next action in the validated workflows.

#### Repository integration

- [ ] Move the executable to `scripts/` and its tests and fixture to `tests/`.
- [ ] Adopt the shared release version constant and public-script provenance
  header.
- [ ] Add npm-lite to `tests/test-versions.sh` and `maintainers/bump-version`.
- [ ] Document installation, scope, wrapper options, logs, and examples in the
  repository README and installation guide.
- [ ] Run the complete `./tests/test-*.sh` suite and the repository's required
  ShellCheck command after moving public files.

### Exit criteria

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

### Non-goals

- General npm output parsing.
- Supporting arbitrary package scripts in compact mode.
- Changing test reporters or package configuration.
- Improving execution time.
- Replacing npm, a task runner, or CI output.

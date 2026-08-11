# `npm-lite` open-source project experiment

Date: 2026-08-10

Status: Complete.

Follow-up: ANSI-normalized TAP counts, complete rendering for short failures,
and marker-aware context for long failures were implemented after this
measurement. The tables below record the behavior of the version originally
measured. Remaining limitations are maintained in
[`docs/npm-lite.md`](../../docs/npm-lite.md#limitations).

## Scope

Matched direct and wrapped `test:unit` runs were measured in three open-source
projects:

| Project | Commit | Runner | Runtime |
| --- | --- | --- | --- |
| [DFE-Digital/dfe-autocomplete](https://github.com/DFE-Digital/dfe-autocomplete) | `0fff185bf6acda09dbb544dd7a6fb8233bef6c80` | Vitest 2.1.9 | Node 22.11.0, npm 10 |
| [architect/sandbox](https://github.com/architect/sandbox) | `517360487e95ebbdf3a95a227bd1cfb0f7f63812` | Tape with `tap-arc` | Node 24.19.0, npm 11 |
| [1Password/op-js](https://github.com/1Password/op-js) | `9ea073e6f7102ae8785e0cf9466ee19a7c803b75` | Jest 29.7.0 | Node 18.18.0, npm 10 |

The checkouts, dependencies, raw outputs, retained logs, runtimes, and
measurement harness remain under the gitignored `npm-experiment/` directory
beside this report.

## Method

Dependencies were installed using `npm ci` for `dfe-autocomplete`, `npm install`
for `architect/sandbox`, and Yarn 1.22.22 with the committed lockfile for
`op-js`. Each direct `npm run test:unit` invocation was followed by
`npm-lite run test:unit` from the same checkout and dependency state.

A dedicated failing assertion was then added to each checkout. The same command
pairs were captured again, after which the assertion files were removed. The
Sandbox suite starts local services, so its measurements ran outside the agent
filesystem and network sandbox. All results combine standard output and
standard error, matching `npm-lite`'s capture behavior.

Elapsed times are recorded for completeness but are not performance evidence.
Run order, caches, and normal machine activity were not controlled.

## Results

| Project | Case | Command | Exit | Time | Bytes | Lines | Words |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| `dfe-autocomplete` | Success | direct npm | 0 | 6.249 s | 2,260 | 43 | 250 |
| `dfe-autocomplete` | Success | `npm-lite` | 0 | 4.377 s | 25 | 1 | 7 |
| `dfe-autocomplete` | Failure | direct npm | 1 | 4.077 s | 2,984 | 64 | 320 |
| `dfe-autocomplete` | Failure | `npm-lite` | 1 | 3.967 s | 3,194 | 69 | 340 |
| `architect/sandbox` | Success | direct npm | 0 | 2.752 s | 136,262 | 1,476 | 10,243 |
| `architect/sandbox` | Success | `npm-lite` | 0 | 2.782 s | 12 | 1 | 4 |
| `architect/sandbox` | Failure | direct npm | 1 | 2.640 s | 136,829 | 1,487 | 10,289 |
| `architect/sandbox` | Failure | `npm-lite` | 1 | 2.885 s | 5,208 | 85 | 412 |
| `op-js` | Success | direct npm | 0 | 4.147 s | 2,491 | 68 | 377 |
| `op-js` | Success | `npm-lite` | 0 | 3.035 s | 24 | 1 | 7 |
| `op-js` | Failure | direct npm | 1 | 4.800 s | 648 | 26 | 70 |
| `op-js` | Failure | `npm-lite` | 1 | 3.334 s | 862 | 32 | 93 |

Successful output fell by 98.89% for Vitest, 99.99% for Tape, and 99.04% for
Jest by bytes. Vitest and Jest counts were preserved:

```text
PASS · 230 tests · 5 s
PASS · 40 tests · 3 s
```

The Tape success became `PASS · 3 s`; `npm-lite` did not recognize `tap-arc`'s
`passing: 1108` count format.

## Advantages demonstrated

- The successful Vitest and Jest runs became one line while preserving the
  runner's test count and npm's exit status.
- The large Tape success fell from 136,262 bytes and 1,476 lines to 12 bytes and
  one line. This is a much stronger high-volume case than the earlier npm
  experiment.
- The large Tape failure fell by 96.19% by bytes and 94.28% by lines. Its full
  136,829-byte log was retained.
- All three induced failures preserved npm's exit status. The Vitest and Jest
  excerpts displayed the failing test, expected and received values, summary,
  and log path.

## Gaps found

### Small failures can become larger

The direct Vitest and Jest failures were already shorter than 80 lines. Adding
the wrapper heading, excerpt notice, and retained-log path made visible output
7.04% larger for Vitest and 33.02% larger for Jest. Bounded failure output is an
advantage only when the underlying failure is sufficiently verbose.

### Tail-only diagnostics can omit the actionable assertion

The induced Tape assertion ran near the beginning of a 1,487-line stream. The
wrapped excerpt showed the final generic failure summary but omitted the test
name and its `actual` and `expected` values. The retained log contained them.
This confirms that a last-80-lines policy can require an immediate second tool
call before an agent knows what to fix.

### A successful exit can still contain a serious error

The unmodified Sandbox command exited zero and reported all 1,108 Tape
assertions passing, but its direct output also contained an uncaught `TypeError`
stack trace from a late asynchronous invocation. The formatter pipeline still
returned success. `npm-lite` printed only `PASS · 3 s` and deleted its success
log, making the stack trace unrecoverable.

This is partly an upstream command-quality problem, but it demonstrates the
risk of discarding all successful output based solely on exit status. The DFE
success also contained a Vite CommonJS API deprecation warning that disappeared
from the compact result.

### TAP counts were unsupported when measured

The count parser recognizes Mocha, Jest, and Vitest summary formats but not
`tap-arc`'s `passing: N` output. The largest suite therefore produced the least
informative success summary. The follow-up implementation added this format.

### Environment requirements still matter

Sandbox's local-server tests failed inside the restricted agent runner and
passed when allowed local networking. A wrapper comparison must first establish
that the direct project command is valid in the measurement environment.

## Conclusion

The experiment supports `npm-lite`'s main claim across Vitest, Jest, and a large
Tape suite: successful agent-visible output can fall by roughly 99% while
preserving command status. It also identifies two meaningful design gaps:
success output can contain important warnings or errors that are deleted, and a
tail-only failure excerpt can omit the actionable assertion.

The implemented follow-up added TAP count parsing and selects failure context
around error markers. Successful commands still trust npm's exit status and
discard their logs; the dedicated `npm-lite` guide documents why suspicious
successful output and masked pipeline failures remain limitations.

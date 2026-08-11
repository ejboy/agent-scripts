# `npm-lite` and direct npm comparison evidence

Date: 2026-08-10

Status: Complete.

## Method

The AIBadger VS Code `verify` workflow was run through `npm run verify` and
`npm-lite run verify` from the same checkout and dependency state. Standard
output and standard error were captured separately. A representative assertion
failure was introduced only in a disposable worktree and tested through both
commands.

## Results

| Case | Command | Exit | Wall time | Bytes | Lines | Words |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Success | direct npm | 0 | 12.739 s | 18,854 | 375 | 2,585 |
| Success | `npm-lite` | 0 | 12.785 s | 26 | 1 | 7 |
| Failure | direct npm | 1 | 12.785 s | 19,208 | 389 | 2,620 |
| Failure | `npm-lite` | 1 | 11.701 s | 3,663 | 85 | 481 |

Both success paths reported 266 passing tests. The wrapped success output was:

```text
PASS · 266 tests · 13 s
```

The failure paths both reported 265 passing tests and one failing test. The
wrapper surfaced the failing test, assertion difference, and stack location,
and retained a 19,208-byte, 389-line raw log matching the size of direct npm's
complete output.

The success output reduction was 99.86% by bytes and 99.73% by lines. The
failure output reduction was 80.93% by bytes and 78.15% by lines.

## Issues and inefficiencies

- The first sandboxed smoke-test attempt recorded by the parent experiment could
  not create the project-local `.agent-logs/npm/` directory. Compact mode needs
  normal project write access for its retained logs.
- Two preliminary measurement-harness attempts failed before producing usable
  paired evidence: zsh's high-resolution timer module was not loaded, then the
  harness used zsh's read-only `status` variable. These were harness mistakes,
  not npm or `npm-lite` failures, and are excluded from the table.
- The two successful runtimes differed by only 0.046 seconds. The experiment
  provides no evidence that `npm-lite` changes execution speed.
- Failure output remains 85 lines because the wrapper conservatively prints a
  bounded diagnostic tail. It is much smaller than direct output but not a
  single-line failure summary.

## Conclusion

For this real verification workflow, `npm-lite` preserved exit status, test
results, and useful failure diagnostics while sharply reducing agent-visible
output. Its benefit is output policy and retained diagnostics, not speed.

# Anonymized Local Observations

Date collected: 2026-08-07

## Method

The source was a search of local project-level tool-observation logs. Project
names, paths, source files, and workspace-specific feature details have been
removed. These are practical observations from agent sessions, not controlled
benchmarks. Reported token sizes were estimates recorded by the sessions.

## Relevant results

| Workflow | Result | Useful information | Approximate visible output |
| --- | --- | --- | ---: |
| `npm run verify`, run A | Success; more than 250 tests passed | Compile and lint status, final test count | 15,000 tokens |
| `npm run verify`, run B | Success; more than 250 tests passed | Compile and lint status, final test count | 4,700 tokens before truncation |
| `npm run test:unit` | Success | Final status and test count | 15,000 tokens |

Across these three observations, successful npm workflows exposed at least
approximately 34,700 tokens. Most of that output enumerated individual passing
tests. No next action depended on those passing-test names.

## Interpretation

The repeated actionable payload was small:

- whether each verification stage passed;
- whether any test failed;
- the final passing-test count; and
- optionally the duration.

This supports experimenting with compact output for the two observed scripts.
It does not yet establish an exact savings percentage because no wrapper output
has been implemented or measured.

## Related observations

Other local commands also produced excessive output, including broad source
searches, multi-file dumps, process listings, and test commands in other build
systems. Those cases are excluded from this experiment because a thin npm
wrapper cannot address them without expanding its scope.

## Full observation-set summary

The complete anonymized set contains 15 observations from five workspaces.
Workspace contributions were 6, 4, 2, 2, and 1 observations respectively.

| Command family | Observations | Typical issue |
| --- | ---: | --- |
| Broad `rg` searches | 4 | Repetitive matches, vendored content, or results truncated before useful candidates |
| Multi-file `sed` inspection | 3 | Unrelated source context displaced the relevant lines |
| npm verification and tests | 3 | Every passing test was listed |
| Other tests and static validation | 4 | Repetitive stack traces, unsupported-format diagnostics, misleading line-ending warnings, or an inconvenient artifact path |
| Process inspection | 1 | Duplicate helper processes and long command lines obscured the target process |

Thirteen of the 15 observations primarily concerned excessive or low-value
output. One concerned a sandbox permission problem caused by a default artifact
path. One concerned diagnostics that treated preserved CRLF line endings as
trailing whitespace.

### Recorded output volume

The logs used two approximate units, so they should not be combined into a
single total:

- Entries measured in tokens recorded approximately 104,700 visible output
  tokens. Some commands were truncated, so this is a lower bound on generated
  output.
- Entries measured in bytes recorded approximately 197 KB.
- One line-ending check recorded four misleading diagnostics rather than an
  output size.
- One screenshot test recorded a single artifact rather than an output size.

The largest individual observations were:

| Command pattern | Recorded size | Main cause |
| --- | ---: | --- |
| Broad documentation search | Approximately 55,000 tokens before truncation | Repetitive matches across a documentation tree |
| Broad source scan including vendored JavaScript | Approximately 98 KB | Minified third-party files were not excluded |
| Full unit-test output | Approximately 15,000 tokens | Passing tests were enumerated |
| Full verification output | Approximately 15,000 tokens | Passing tests were enumerated |
| Combined multi-file source inspection | Approximately 10,000 tokens before truncation | Too many files were read together |

### Common successful follow-ups

The observations repeatedly converged on a small set of better approaches:

- Narrow searches to a target file, directory, symbol, heading, or status field.
- Exclude generated, vendored, and minified content from structural scans.
- Locate relevant lines with `rg`, then inspect only bounded ranges with `sed`.
- Run focused tests during iteration and retain only stage status, failures,
  duration, and final counts for broad verification.
- Query only the main process or extension-host process instead of listing an
  entire process family.
- Use format-aware checks when legacy HTML or CRLF files make generic validators
  noisy or misleading.
- Give generated artifacts an explicit temporary output path in sandboxed runs.

### Possible future experiments

The data may support experiments separate from `npm-lite`:

1. A bounded search helper that requires focused paths, excludes common vendored
   trees, and reports truncation explicitly.
2. A source-inspection helper that resolves matches first and emits small context
   windows instead of complete files.
3. Compact wrappers for other test runners that preserve raw failed output.
4. A targeted development-host status command that reports only the relevant
   process identities and state.
5. Validator-specific guidance for legacy markup and mixed line endings.

## Limitations

- All three npm observations came from one anonymized workspace.
- The full set is small and was collected opportunistically rather than sampled
  across a defined project population.
- Only successful runs were recorded in this subset.
- One output estimate was already affected by truncation.
- Test counts and output vary as the project changes.
- Token reduction must be measured after implementation; it is not inferred as
  runtime or build-performance improvement.

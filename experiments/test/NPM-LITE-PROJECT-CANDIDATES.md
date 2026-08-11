# `npm-lite` open-source project candidates

Date: 2026-08-10

Status: Candidate research complete; the first batch was measured in
[`NPM-LITE-OPEN-SOURCE-EXPERIMENT.md`](NPM-LITE-OPEN-SOURCE-EXPERIMENT.md).

## Goal

Broaden the current `npm-lite` evidence beyond AIBadger's Mocha-based
`verify` workflow. The best next experiments should either demonstrate compact
output with a different test runner or expose a specific compatibility gap.

`npm-lite` only compacts these exact invocations:

```text
npm-lite run verify
npm-lite run test:unit
```

The project must therefore already define one of those script names. Renaming a
project script just for an experiment would not test real-world compatibility.

## Recommended projects

| Priority | Project | Existing script | Runner | What it tests |
| --- | --- | --- | --- | --- |
| 1 | [DFE-Digital/dfe-autocomplete](https://github.com/DFE-Digital/dfe-autocomplete) | `test:unit`: `vitest run test/unit/` | Vitest | Best small, npm-native positive case; has `package-lock.json` and should exercise the supported `Tests N passed` count parser. |
| 2 | [architect/sandbox](https://github.com/architect/sandbox) | `test:unit`: `cross-env tape 'test/unit/**/*-test.js' \| tap-arc` | Tape/TAP | Best count-parser gap case; a passing run should compact successfully but likely omit the test count because TAP summaries are not recognized. It also tests output passing through a formatter pipeline. |
| 3 | [1Password/op-js](https://github.com/1Password/op-js) | `test:unit`: `jest --testMatch '<rootDir>/src/*.test.ts'` | Jest | Best small Jest case: 27 tracked files, seven test files, and 20 declared dependencies. It uses Yarn's lockfile, so install with Yarn and use npm only to invoke the script. |
| 4 | [windmill-labs/windmill frontend](https://github.com/windmill-labs/windmill/blob/main/frontend/package.json) | `test:unit`: `vitest` | Vitest watch mode | Best command-shape gap case. The exact compact command may wait in watch mode; adding `-- --run` makes it suitable for automation but causes `npm-lite` to pass through instead of compacting. The repository is large, so confirm this gap after the smaller projects. |

All five repositories were active and unarchived when checked on 2026-08-10.
Their licenses were also identifiable as open source: MIT for
`dfe-autocomplete` and `op-js`; Apache-2.0 for `sandbox`;
and predominantly AGPLv3 for Windmill's frontend, subject to the exceptions in
that repository's license notice.

`microsoft/vscode-cdp-proxy` was considered because it is tiny and has an exact
`test:unit` script, but its current tree contains no tests. It is therefore an
obsolete-script edge case, not a representative control project.

## Practicality of the first batch

| Project | Repository shape | Setup | Practical assessment |
| --- | --- | --- | --- |
| `dfe-autocomplete` | 138 tracked files, 24 test files, 27 declared dependencies | `npm ci`; unit script has no pre/post hook or external service | Easy. The repository also contains Ruby code, but the selected Node unit command is isolated. |
| `architect/sandbox` | 398 tracked files, 293 test files, 33 declared dependencies | Node 22 or newer and `npm install`; no committed lockfile | Moderate, but valuable. It is still only about 2.6 MiB in GitHub's repository-size metric; the large unit suite should create the kind of noisy output `npm-lite` targets. Lack of a lockfile slightly weakens reproducibility. |
| `op-js` | 27 tracked files, seven test files, 20 declared dependencies | Install from `yarn.lock`, then invoke the script through npm | Easy. The mixed Yarn-install/npm-run procedure must be stated explicitly, but no service or build prerequisite is apparent. |

## Expected findings

### Stronger advantage evidence

Run `dfe-autocomplete` first. It is a compact npm project with a non-watch
Vitest command and npm lockfile, so it adds ecosystem breadth without making
package-manager behavior part of the result. Compare direct and wrapped success
and failure output using the same checkout and installed dependency state.

Run `op-js` as the third runner. The only notable wrinkle is using Yarn for the
dependency installation before comparing `npm run test:unit` with
`npm-lite run test:unit`; the test itself is small and self-contained.

### Likely gaps

1. **Arguments disable compact mode.** The current mode check requires exactly
   two arguments. Commands such as `npm-lite run test:unit -- --run`, a common
   way to turn Vitest watch mode into a one-shot run, silently use passthrough
   mode. Windmill demonstrates the practical effect.
2. **TAP counts are not recognized.** The parser recognizes Mocha, Jest, and
   Vitest-style summaries only. `architect/sandbox` should produce `PASS · N s`
   without a count even when TAP reports one.
3. **Successful warnings disappear.** All output is discarded after a zero exit
   status. Deprecations, flaky-test warnings, skipped-test notices, coverage
   threshold warnings, and worker-leak warnings are therefore unavailable.
   Each project run should explicitly inspect the raw direct success output for
   actionable warnings before calling the reduction an unqualified advantage.
4. **Project-local logging requires a writable checkout.** Compact mode creates
   `.agent-logs/npm` before running npm, even for success. A read-only source tree
   fails before the test command starts.
5. **Package-manager scope is narrower than script compatibility.** A project
   may define a compatible script but use Yarn or pnpm for dependency
   installation. Experiments must distinguish runner-output compatibility from
   claims that `npm-lite` is the project's supported package-manager frontend.
6. **The failure excerpt is tail-biased.** Only the last 80 lines and 7,000 bytes
   are visible. Multi-package or concurrent failures can put the first and most
   useful error outside the excerpt. A deliberately failing Tape pipeline is a
   useful first check; a monorepo should follow if that remains inconclusive.

## Measurement sequence

For each selected repository:

1. Record the commit, Node/npm versions, installation command, and clean status.
2. Install once using the repository's committed lockfile and documented
   package manager.
3. Capture direct and wrapped success runs in alternating order.
4. Introduce one small assertion failure in a disposable worktree and capture
   the same pair again.
5. Compare exit status, bytes, lines, wall time, reported test count, visible
   diagnostic usefulness, and retained-log completeness.
6. Restore by deleting the disposable worktree, not by modifying the source
   checkout used for success measurements.

Do not treat small runtime differences as performance evidence. The useful
claim is reduced agent-visible output with preserved status and recoverable
diagnostics.

## Suggested first batch

The highest-value batch is `dfe-autocomplete`, `architect/sandbox`, and `op-js`.
Together they provide Vitest positive evidence, a substantial TAP parser
challenge, and a small Jest case while keeping checkout and installation cost
modest. Windmill should be documented as a confirmed interface gap with a
minimal local fixture before paying the cost of a full repository experiment.

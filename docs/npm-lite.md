# npm-lite

`npm-lite` reduces successful output for two selected npm workflows and direct
Node test runs. Direct non-test Node commands pass through to Node unchanged.

## Usage

These invocations use compact mode:

```bash
npm-lite run verify
npm-lite run test:unit
npm-lite node --test path/to/test.js
npm-lite node --test --test-name-pattern 'dashboard' path/to/test.js other.test.js
```

The `node --test` form supports multiple test paths and forwards Node test
options. Node watch options pass through directly so watch output remains live.
Other npm commands and commands with additional arguments pass through to npm
unchanged:

```bash
npm-lite install
npm-lite run build
npm-lite run test:unit -- --run
npm-lite node --test --watch path/to/test.js
npm-lite node script.js
```

## Output and logs

Successful compact runs print the elapsed time and a test count when a supported
runner summary is present:

```text
PASS · 230 tests · 4 s
```

The count parser recognizes common Mocha, Jest, Vitest, and TAP summary formats,
including Node's `pass N` test summary, after removing ANSI color sequences.

Failures preserve the underlying runner's exit status and retain complete
output under `.agent-logs/npm/`. Failures of at most 80 lines and 7,000 bytes
are printed in full. For larger failures, `npm-lite` selects bounded context
around the first and last error markers and includes the final runner summary.
The retained log is authoritative.

Failed runner logs older than seven days are pruned on later compact runs. Move
any log that must be retained longer. Projects adopting `npm-lite` should
ignore `.agent-logs/`.

## Limitations

- Compact mode trusts the underlying runner's exit status. A project script whose pipeline masks
  a child failure can be reported as successful.
- Successful output is discarded. Warnings, deprecations, or error-looking
  text emitted by a command that exits zero are not retained. Automatically
  classifying such text is intentionally deferred because tests often print
  expected warnings and errors.
- A short wrapped failure can be slightly larger than direct npm output because
  the wrapper adds its status and retained-log path. Failure output is bounded;
  it is not guaranteed to be smaller in every case.
- Error-context selection is heuristic. Consult the retained raw log when the
  selected diagnostics do not identify the next action.
- Compact mode needs write access to the current project to create
  `.agent-logs/npm/`.

## Evidence

The [open-source project experiment](../experiments/test/NPM-LITE-OPEN-SOURCE-EXPERIMENT.md)
contains matched Vitest, Tape, and Jest measurements and the evidence behind
these limitations.

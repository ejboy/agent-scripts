# npm-lite Experiment

Experimental thin wrapper for reducing coding-agent output from two noisy npm
scripts:

```text
npm-lite run verify
npm-lite run test:unit
```

Only those exact invocations are candidates for compact output. Every other
invocation must pass through to `npm` with unchanged arguments and exit status.

This experiment is self-contained and is not part of the public `scripts/`
interface or repository release tooling.

Documents:

- [PLAN.md](PLAN.md) — proposed behavior and implementation sequence
- [LOCAL-OBSERVATIONS.md](LOCAL-OBSERVATIONS.md) — anonymized evidence motivating
  the experiment

Experimental executable: `./npm-lite` (from this directory).

## agent-complaint

`agent-complaint` is an experimental, npm-independent observation collector
that coding agents can use when developer tooling is noisy, misleading,
difficult to parse, unnecessarily expensive, or otherwise unfriendly. It
accepts a command and a concise description, then appends one JSONL record to
a local user file. It does not execute or inspect the command, capture output,
or send telemetry anywhere; reports remain local.

Run `./test-agent-complaint.sh` to validate it. If this proves useful, it may
eventually graduate into the public `agent-scripts` collection.

## Instrumentation

Every invocation appends one JSON object to
`~/.agent-scripts/npm-stats.jsonl`. Compact runs record raw and visible byte and
line counts. Pass-through runs record the invocation, duration, and exit status
without piping or measuring npm output.

Set `NPM_LITE_STATS=0` to disable collection or `NPM_LITE_STATS_FILE` to choose a
different file. Instrumentation is experiment-only and will not graduate into
the public version.

## Validation

```bash
./test-npm-lite.sh
shellcheck --severity=warning ./npm-lite ./test-npm-lite.sh ./fixtures/fake-npm
```

# Agent Output Experiments

This directory preserves the roadmap and experiments for reducing low-value
coding-agent tool output. `npm-lite` graduated to the public
[`scripts/npm-lite`](../../scripts/npm-lite) interface. `agent-complaint` remains
explicitly experimental and collects local evidence for future candidates.

## npm-lite

The `npm-lite` experiment produced a thin wrapper for reducing coding-agent
output from two noisy npm scripts:

```text
npm-lite run verify
npm-lite run test:unit
```

Only those exact invocations are candidates for compact output. Every other
invocation must pass through to `npm` with unchanged arguments and exit status.

The production implementation now lives in `scripts/npm-lite`; the experiment
history below remains for context and evidence. It is part of the public
interface, not repository release tooling.

Documents:

- [PLAN.md](PLAN.md) — broader agent-friendly tooling roadmap and detailed
  `npm-lite` graduation plan
- [LOCAL-OBSERVATIONS.md](LOCAL-OBSERVATIONS.md) — anonymized evidence motivating
  the experiment

## agent-complaint

`agent-complaint` is an experimental, npm-independent observation collector
that coding agents can use when developer tooling is noisy, misleading,
difficult to parse, unnecessarily expensive, or otherwise unfriendly. It
accepts a command and a concise description, then appends one JSONL record to
a local user file. Each record includes the basename of the working directory,
not its full path. It does not execute or inspect the command, capture output,
or send telemetry anywhere; reports remain local.

Run `./test-agent-complaint.sh` to validate it. If this proves useful, it may
eventually graduate into the public `agent-scripts` collection.

## Validation

```bash
./test-agent-complaint.sh
shellcheck --severity=warning ./agent-complaint ./test-agent-complaint.sh
```

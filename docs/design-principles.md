# Design principles

## Token-efficient output

Routine build logs can displace source code, instructions, and the actual failure from a coding agent's context. `mvn-lite` makes successful Maven runs very small and shows only conservative, actionable failure evidence by default.

## Lossless diagnostics

Compact output is a presentation layer, not a replacement for diagnostics. `mvn-lite` preserves Maven's exit status, retains failure logs, offers `--full` and `--raw`, and can retain successful logs with `--keep-log`. The raw log is always authoritative.

## Build-oriented scope

`mvn-lite` is optimized for common build, test, package, install, and verification workflows. It does not attempt to classify every reporting or inspection goal. Ordinary Maven output remains available through `--full`, and Maven help and version commands pass through automatically.

## High-value coverage over completeness

`mvn-lite` prioritizes the Maven workflows and failure modes most valuable during local development. It aims to handle common cases exceptionally well rather than model every Maven goal, plugin, and output format. Rare cases should fall back predictably to ordinary Maven output or the retained raw log, and should be added only when real usage demonstrates sufficient value.

## Fast defaults

The smallest useful verification command should be easy to run. `mvn-lite` adds only output-oriented Maven settings in compact mode; it does not choose modules, goals, profiles, or test tiers.

## Predictable command vocabularies

Closeness to Maven reduces learning cost, agent instructions, unexpected behavior, and migration effort. A user can replace `mvn test` with `mvn-lite test` without learning a new build vocabulary, while accepting that the wrapper is not a complete drop-in replacement for every reporting goal.

## Bounded, conservative extraction

The parser recognizes a small set of high-value compiler, test, dependency, plugin-goal, and Maven command failures. Findings are deduplicated and capped. Unknown formats receive a bounded log tail instead of a fabricated interpretation.

## Repository-local adoption

A committed wrapper is reviewable and versioned with an application. It can be referenced precisely from `AGENTS.md`. `mvn-lite` still behaves like Maven by operating in the caller's current working directory, finding that project's `./mvnw`, and writing logs under that project.

## Deterministic processing

The scripts use Bash and standard operating-system tools. They do not call an LLM, require an API key, send telemetry, inspect POMs, or make nondeterministic guesses.

## Generic scripts versus project wrappers

Generic cross-project wrappers—such as compact Maven output and predictable browser startup—belong here. Module names, test tiers, ports, services, and verification policy belong in the application repository.

## Local discoverability

Local tools can expose lightweight, deterministic CLI metadata so agents can discover useful repositories and capabilities without each project duplicating machine-specific instructions.

## Failure behavior

Scripts fail loudly when required tools or resources are unavailable. On Maven failure, `mvn-lite` reports recognized evidence, points to the complete raw log, and suggests `--full`. It does not echo Maven arguments in compact failure output because command lines may contain sensitive values.

# Static guidance and `repo-map` discovery comparison evidence

Date: 2026-08-10

Status: Complete.

## Method

Two ephemeral Codex sessions received the same read-only task: find AIBadger's
public CLI repository and report its Go module path and command-entrypoint
directory. One session received a static absolute repository path. The other
received guidance to use `repo-map`. Both sessions began in otherwise minimal
fixture directories.

Approval wait time was not treated as agent execution time. The comparison is a
single paired observation, not a statistical agent benchmark.

## Results

| Property | Static path | `repo-map` guidance |
| --- | ---: | ---: |
| Correct repository | Yes | Yes |
| Correct module and entrypoint | Yes | Yes |
| Shell command executions | 2 | 5 |
| Unrelated repository contents read | 0 | 0 |
| Repository metadata exposed | One target | Full registry listing |
| Clarification or correction | None | None |

Both sessions returned the same module and `cmd/badger` entrypoint. The static
session immediately inspected the supplied repository. The discovery session
inspected its fixture, checked help, ran `repo-map list`, then redundantly ran
both `repo-map show aibadger` and `repo-map get aibadger` before inspecting the
target.

## Issues and inefficiencies

- In this trial, `repo-map` required more discovery commands than a correct
  static path. It did not reduce command count or prompt/context consumption.
- `repo-map list` disclosed metadata for every registered repository even though
  the task needed one. The agent could have used a known alias directly, but the
  generic guidance did not provide that alias.
- The discovery agent used both `show` and `get`; either result already contained
  the path. More targeted guidance could avoid this redundant call.
- An initial discovery trial used a strictly read-only sandbox. At the time of
  the trial, `repo-map list` attempted temporary-file creation even for read-only
  operations. The agent worked around this by reading the registry directly,
  which exposed implementation and registry details and confounded the
  comparison. That trial was discarded and rerun with registry access. This
  limitation has since been fixed and is covered by regression tests.
- Token-usage values from the two sessions are not meaningfully comparable
  because session-level cached context differed.

## Conclusion

`repo-map` successfully replaced a machine-specific path and selected the right
repository without reading unrelated source trees. This one task also shows its
cost: generic discovery took more commands and exposed broader metadata than a
correct static path. Guidance should name a stable alias when the target is
known and reserve `list` for genuinely open-ended discovery.

## Post-fix rerun: 2026-08-10

Two new ephemeral Codex sessions repeated the same read-only task from empty
fixture directories under a strict read-only agent sandbox. The static session
received the same repository path. The discovery session received the known
`aibadger` alias and the current instruction to use `repo-map get aibadger`
without listing repositories.

| Property | Static path | Targeted `repo-map` guidance |
| --- | ---: | ---: |
| Correct repository | Yes | Yes |
| Correct module and entrypoint | Yes | Yes |
| Shell command executions | 2 | 2 |
| Repositories inspected | 1 | 1 |
| Unrelated repository contents read | 0 | 0 |
| Repository metadata exposed | One target | One target |
| Clarification or correction in final run | None | None |

Both sessions again reported the same module and `cmd/badger` entrypoint. The
targeted session called `repo-map get aibadger` once and then inspected only the
resolved repository. The lookup exited 0 and emitted one line (45 bytes in this
environment); it did not print any unrelated registry aliases or metadata.

An initial guided rerun exposed a remaining shell-level temporary-file write in
the registry parser. That implementation issue was corrected before the final
paired run and is detailed in the failure and portability report. No prompt
clarification or behavioral correction was required in the final run.

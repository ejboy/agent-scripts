# `repo-map` failure and portability evidence

Date: 2026-08-10

Status: Complete.

## Method

Each case used an isolated temporary home directory and registry fixture. The
live user registry was never modified. Fixtures contained generic descriptions
and paths except for two existing repository paths used to verify explicit
aliases.

## Results

| Case | Exit | Result |
| --- | ---: | --- |
| No user registry | 0 | Listed built-in `agent-scripts` capabilities only |
| Missing registered directory, `list` | 0 | Listed the repository with `[missing]` |
| Missing registered directory, `get` | 1 | Named the missing path |
| Unknown repository name | 1 | Reported `unknown repository` and the requested name |
| Malformed registry record | 1 | Reported the malformed repository record |
| Two explicit aliases | 0 | Listed both aliases and resolved their distinct paths |
| Copied registry with old paths | 0 | Listed stale entries with `[missing]` |
| Registered command absent from `PATH` | 1 | Marked the command `missing` with path `-` |

The explicit-alias fixture represented public and private dashboard repositories
whose upstream names can overlap. Distinct local aliases resolved without
ambiguity; `repo-map` does not infer aliases from Git remotes.

## Issues and inefficiencies

- `list` deliberately exits successfully for stale paths and relies on the
  `[missing]` marker. Automation that requires a usable path must call `get` or
  inspect the marker rather than treating `list` success as validation.
- A copied registry does not rewrite paths or offer a migration mechanism. Its
  failure is visible but remediation is manual.
- Error messages are immediate and actionable, but there is no suggestion to
  run `repo-map add` or edit the local registry.
- At the time of this experiment, read-only commands needed permission to create
  a temporary file near the registry. This limitation has since been fixed and
  is covered by regression tests.

## Conclusion

The tested failure cases were safe and understandable. Missing paths and
commands were not silently treated as usable, malformed data failed early, and
explicit aliases handled duplicate upstream naming. Portability remains manual,
and the read-only sandbox limitation observed during the experiment has since
been resolved.

## Post-fix rerun: 2026-08-10

The read-only cases were rerun against the live registry inside a macOS sandbox
profile that denied all filesystem writes except writes to `/dev/null`. The
first attempt found that Bash's here-string used by the registry parser still
created a temporary file even though the script no longer called `mktemp` for
read-only operations. The parser was changed to consume `printf` output through
process substitution instead.

After that correction, both targeted operations passed in the strict profile:

| Operation | Exit | Output | Unrelated entries printed |
| --- | ---: | ---: | ---: |
| `repo-map get aibadger` | 0 | 1 line, 45 bytes | 0 |
| `repo-map command html-screenshot` | 0 | 5 lines, 178 bytes | 0 |

The repository lookup printed only the resolved target path. The command lookup
printed only the named capability's repository, availability, resolved path,
and description. This rerun closes the strict read-only limitation while also
showing why blocking only the external `mktemp` executable was insufficient
evidence.

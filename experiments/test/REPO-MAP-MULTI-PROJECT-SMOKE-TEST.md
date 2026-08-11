# `repo-map` multi-project smoke test

Date: 2026-08-10

Status: Baseline complete; post-fix rerun planned.

Publication note: Project and repository names are retained where they make the
results understandable. Published evidence excludes private source, plans,
registry contents, machine paths, and other private implementation details.

## Post-fix rerun checklist

- [ ] Verify read-only `repo-map` operations in a strict read-only sandbox.
- [ ] Verify targeted repository resolution without listing unrelated entries.
- [ ] Verify targeted command resolution without listing unrelated capabilities.
- [ ] Rerun the fresh-session discovery comparison and record command count,
  exposed metadata, and any correction required.
- [ ] Verify `launch-browser` against its documented managed-session reuse policy.
- [ ] Verify successful `html-screenshot` output excludes non-actionable Chrome
  diagnostics.
- [ ] Add dated rerun results to the supplemental reports without replacing the
  baseline.

## Context

Several local project guidance files were simplified to use `repo-map` for
discovering related repositories and shared agent-oriented tools. Exact
project-specific commands remain documented where they define an established
build, test, or browser workflow.

This experiment checked whether the resulting guidance works across a varied set
of real repositories and workspaces. It was a compatibility and discovery smoke
test, not a controlled comparison of output volume, execution time, or agent task
quality.

Finrecord was excluded because its guidance and workflow had already been tested
separately and the repository was under active development during this run.

## Scope

`repo-map list` and `repo-map commands` were invoked from nine locations:

- Badger workspace
- AIBadger
- AIBadger VS Code
- Badger Sidecar
- Badger Cert
- Projctl
- Scriptella workspace
- StatLite
- Website

The test also resolved the 11 in-scope registered repositories used by those
projects:

- `aibadger`
- `aibadger-vscode`
- `badger-sidecar`
- `badger-cert`
- `homebrew-tap`
- `projctl`
- `scriptella-etl`
- `scriptella.github.io`
- `statlite`
- `statlite-private`
- `pvrlabs-site`

## Results

| Check | Result |
| --- | --- |
| `repo-map list` from all nine locations | Passed |
| `repo-map commands` from all nine locations | Passed |
| Resolve all 11 in-scope repository names to present directories | Passed |
| Resolve `homebrew-tap` for release guidance | Passed |
| Resolve `statlite-private` for private planning guidance | Passed |
| Discover the `badger` command under `aibadger` | Passed |
| Find shared commands by name on `PATH` | Passed |
| `badger --version` and `badger --help` | Passed; installed version `0.3.0` |
| Scriptella `mvn-lite --help-mvn-lite` | Passed |
| Website browser-helper help commands | Passed |
| AIBadger VS Code `npm-lite run verify` | Passed; 266 tests in 13 seconds |

The shared commands checked on `PATH` were `repo-map`, `mvn-lite`, `npm-lite`,
`launch-browser`, `html-screenshot`, and `badger`. The test invoked commands by
name rather than through machine-specific script paths.

The AIBadger VS Code verification produced one agent-visible success line:

```text
PASS · 266 tests · 13 s
```

Its first sandboxed attempt could not create the project-local
`.agent-logs/npm/` directory. The same documented command passed after it was
given normal project write access. This was an execution-environment restriction,
but it confirms that the wrapper expects permission to create its local log
directory.

## Findings

The smoke test supports three narrow conclusions:

1. `repo-map` can replace duplicated machine-specific repository paths in the
   tested guidance while preserving access to related repositories.
2. `repo-map commands` can act as a shared command catalog when the advertised
   commands are installed on `PATH` and invoked by name.
3. Repository guidance can use discovery for shared capabilities while retaining
   exact commands for established project workflows.

The test does not establish that every wrapper reduces output, improves task
completion, or behaves correctly for every success and failure scenario.

## Smoke-test limitations

The initial smoke-test phase had the following limitations. The linked
follow-ups address most of them with controlled cases while retaining their own
stated scope and limitations.

- This was one machine with one populated local registry.
- Repository discovery was not tested with a fresh, missing, stale, or malformed
  registry.
- The test did not compare agent behavior with and without `repo-map` guidance.
- The successful `npm-lite` run was not compared with direct `npm` output.
- The Maven check exercised wrapper help only; existing experiments contain the
  real-project `mvn-lite` evidence.
- Browser helpers were checked through their help paths. No browser was launched
  and no page was rendered.
- No failure was deliberately introduced into a real project workflow.
- Timing and output-size measurements were not collected for repository discovery.

## Follow-up experiments

The controlled follow-ups were completed as separate experiments:

- [`npm-lite` and direct npm comparison](extras/repo-map-multi-project/NPM-LITE-DIRECT-COMPARISON.md)
- [Static guidance and `repo-map` discovery comparison](extras/repo-map-multi-project/REPO-MAP-DISCOVERY-COMPARISON.md)
- [`repo-map` failure and portability cases](extras/repo-map-multi-project/REPO-MAP-FAILURE-PORTABILITY.md)
- [Browser helpers and direct Chrome comparison](extras/repo-map-multi-project/BROWSER-HELPER-DIRECT-COMPARISON.md)
- [Extended real-project build-wrapper evidence](extras/repo-map-multi-project/BUILD-WRAPPER-EXTENDED-EVIDENCE.md)

The follow-ups confirmed the smoke test's narrow compatibility result while
adding important qualifications. In a paired fresh-session task, `repo-map`
selected the right repository but took five shell commands versus two with a
correct static path and exposed the full registry listing. Strictly read-only
execution also revealed unnecessary temporary-file creation by a read-only
`repo-map` operation.

The output wrappers preserved results and exit statuses while sharply reducing
successful output. They did not improve execution speed. Browser screenshots
were byte-identical to direct Chrome output, but `launch-browser` failed instead
of reusing an existing managed DevTools session and `html-screenshot` still
surfaced some non-actionable Chrome diagnostics.

## Conclusion

The multi-project smoke test passed for repository discovery, command discovery,
and the representative safe workflows exercised. The follow-ups establish large
output reductions for the tested npm and Maven workflows, deterministic browser
screenshots, retained failure evidence, and actionable registry failures.

They also show that simplified discovery guidance is not unconditionally more
efficient: a known correct static path required fewer commands in the paired
task. `repo-map` remains useful for portable machine-local discovery, but known
targets should use stable aliases, read-only operations should work in strict
read-only sandboxes, and managed-browser reuse needs correction or clearer
documentation.

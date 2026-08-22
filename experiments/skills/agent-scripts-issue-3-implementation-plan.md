# Implementation Plan: Agent Skills and Simple Installer

Issue: `ejboy/agent-scripts#3`  
Status: Proposed  
Scope: `repo-map`, `mvn-lite`, `npm-lite`, and `go-lite`

## Objective

Make Agent Scripts easier for users and coding agents to discover and install
with minimal changes.

The issue has four primary outcomes:

1. Make the four current core tools consistent and easy to use.
2. Publish conventional Agent Skills for those four tools.
3. Add a simple one-command installer that preserves the existing repository-based
   installation model.
4. Make Skills support visible in the README, including the Skills badge.

This is primarily a distribution and discoverability change. Keep the
implementation conventional and small. Do not turn the installer into a package
manager or add machinery for edge cases that are unlikely to matter for the
current project.

## Phase 1: Make the four core tools consistent

### Implementation

- [ ] Add `go-lite` to the built-in command capabilities reported by `repo-map`.
- [ ] Preserve the existing useful `repo-map` command-discovery behavior.
- [ ] Ensure each core command has a wrapper-specific help path that does not
  require the underlying toolchain:
  - `repo-map --help`
  - `mvn-lite --help-mvn-lite`
  - `npm-lite --help-npm-lite`
  - `go-lite --help-go-lite`
- [ ] Keep the wrappers within their existing supported scope:
  - `mvn-lite` continues to cover its existing Maven workflows.
  - `npm-lite` continues to compact only its supported npm/Node workflows.
  - `go-lite` continues to compact only `go test`.
- [ ] Preserve normal-tool fallback/pass-through behavior outside supported
  workflows.
- [ ] Preserve `mvn-lite` preference for executable `./mvnw` when present.

### Exit criteria

- [ ] Existing tool tests pass.
- [ ] `repo-map commands` reports all four core tools.
- [ ] All four commands expose toolchain-independent help.

## Phase 2: Add four conventional Agent Skills

### Layout

```text
.agents/skills/repo-map/SKILL.md
.agents/skills/mvn-lite/SKILL.md
.agents/skills/npm-lite/SKILL.md
.agents/skills/go-lite/SKILL.md
```

Each Skill directory should contain only `SKILL.md`.

### Common Skill behavior

- [ ] Use only `name` and `description` in YAML frontmatter.
- [ ] Put narrow activation guidance in the description.
- [ ] Keep each Skill short and focused.
- [ ] Respect project instructions before Skill preferences.
- [ ] Prefer the corresponding Agent Scripts command only when it is available
  and the requested workflow is supported.
- [ ] Fall back to the normal project command when the wrapper is unavailable.
- [ ] Never download or install Agent Scripts automatically.
- [ ] Do not claim capabilities beyond the underlying wrapper.

### Skill-specific behavior

#### `repo-map`

- [ ] Trigger when locating registered or related local repositories.
- [ ] Trigger when discovering commands registered through `repo-map`.
- [ ] Do not describe it as a source-tree, symbol, or architecture mapping tool.
- [ ] If unavailable, use the current workspace or ask the user for the
  repository location instead of starting a broad filesystem search.

#### `mvn-lite`

- [ ] Prefer `mvn-lite` for supported Maven build/test workflows.
- [ ] Fall back to `./mvnw` when present, otherwise `mvn`.
- [ ] Mention `--full` only as a diagnostic fallback.

#### `npm-lite`

- [ ] Prefer `npm-lite` only for its currently supported workflows.
- [ ] Use normal npm/Node commands for unsupported workflows.
- [ ] Do not imply that arbitrary npm commands receive compact output.

#### `go-lite`

- [ ] Prefer `go-lite` for `go test`.
- [ ] Fall back to `go test`.
- [ ] Do not describe it as a compact Go build wrapper.

### Validation

- [ ] Validate Skill frontmatter and directory names.
- [ ] Confirm repository discovery:

  ```bash
  npx skills add . --list
  ```

- [ ] Confirm all four expected Skill names are listed.
- [ ] Perform one isolated noninteractive install from the local checkout, for
  example with a temporary `HOME`:

  ```bash
  npx skills add . --global --agent codex --yes
  ```

- [ ] Statically confirm each Skill contains the required fallback behavior.

Do not add a dedicated agent-evaluation harness for this issue.

### Exit criteria

- [ ] Four valid Skills are discoverable through the normal Skills convention.
- [ ] Trigger descriptions are narrow enough to avoid obvious over-activation.
- [ ] Each Skill documents a normal-tool fallback.
- [ ] Skills do not install binaries or invoke the command installer.

## Phase 3: Add a simple repository installer

### Goal

Automate the existing README installation model:

```text
~/.local/share/agent-scripts/
```

contains the repository, and its `scripts/` directory contains the commands.

The installer should preserve that model rather than introduce a separate
installation layout.

### User-facing command

```bash
curl -fsSL https://raw.githubusercontent.com/ejboy/agent-scripts/main/install.sh | bash
```

### Installation strategy

Install the repository to:

```text
~/.local/share/agent-scripts
```

Use the simplest available transport:

1. If `git` is available:
   - clone the repository when it is not installed;
   - use the existing checkout as the installed repository;
   - allow normal future updates with `git pull`.

2. If `git` is unavailable:
   - download the repository archive with `curl`;
   - extract the complete repository snapshot to the same installation path;
   - updating means rerunning the installer.

Do not attempt to reproduce or download `.git` metadata in archive mode.

### Core command symlinks

Create `~/.local/bin` if necessary and expose only the explicitly promoted core
commands:

```text
~/.local/bin/repo-map -> ~/.local/share/agent-scripts/scripts/repo-map
~/.local/bin/mvn-lite -> ~/.local/share/agent-scripts/scripts/mvn-lite
~/.local/bin/npm-lite -> ~/.local/share/agent-scripts/scripts/npm-lite
~/.local/bin/go-lite  -> ~/.local/share/agent-scripts/scripts/go-lite
```

Only these four commands are symlinked automatically. This avoids surprising
users by exposing every executable in the repository while still making the
main tools immediately available when `~/.local/bin` is already on `PATH`.

Future core tools can be added explicitly to this list.

### PATH behavior

The installer must not edit `.zshrc`, `.bashrc`, `.profile`, `/etc/paths`, or
other shell configuration.

After installation:

- [ ] If `~/.local/bin` is already on `PATH`, state that the four core commands
  are ready to use.
- [ ] Otherwise, explain that the symlinks were created but `~/.local/bin` is not
  currently on `PATH`.
- [ ] In either case, recommend the existing full-repository PATH setup for users
  who want all current and future Agent Scripts:

  ```bash
  export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
  ```

- [ ] Tell users to add that line to their shell startup file if they want the
  complete script collection available in future sessions.

Adding the complete `scripts/` directory to `PATH` is the preferred long-term
setup because newly added scripts become available naturally after updating the
repository.

### Installer behavior

- [ ] Support macOS and Linux.
- [ ] Require Bash and curl.
- [ ] Prefer Git when available, but do not require it.
- [ ] Never invoke `sudo`.
- [ ] Never modify shell startup files.
- [ ] Reject an unset or unusable `HOME`.
- [ ] Reject unsupported operating systems with a clear nonzero error.
- [ ] Preserve the conventional installation directory:
  `~/.local/share/agent-scripts`.
- [ ] Ensure the installed repository contains:
  - `scripts/repo-map`
  - `scripts/mvn-lite`
  - `scripts/npm-lite`
  - `scripts/go-lite`
  - `.agents/skills`
- [ ] Run `bash -n` on the four core scripts before completing installation.
- [ ] Ensure the four core scripts are executable.
- [ ] Create or refresh the four core symlinks in `~/.local/bin`.
- [ ] Rerunning the installer succeeds.
- [ ] Print the installation directory, installation mode (`git` or archive),
  core command names, and PATH guidance.

### Existing installation behavior

Keep this simple:

#### Existing Git checkout

If `~/.local/share/agent-scripts/.git` exists:

- [ ] Recognize it as an existing Git installation.
- [ ] Do not destroy or replace it with an archive.
- [ ] Refresh the core command symlinks.
- [ ] Tell the user that the checkout can be updated with:

  ```bash
  git -C "$HOME/.local/share/agent-scripts" pull --ff-only
  ```

The installer may perform a safe fast-forward update if that remains simple,
but automatic Git update behavior is not required for issue #3.

#### Existing archive installation

If the installation directory exists without `.git`:

- [ ] Rerunning the installer may replace it with a fresh archive snapshot.
- [ ] Stage and validate the new snapshot before replacement.
- [ ] Refresh the four core command symlinks afterward.

No migration or ownership database is required.

### Uninstall

Document the straightforward removal:

```bash
rm -f "$HOME/.local/bin/repo-map"       "$HOME/.local/bin/mvn-lite"       "$HOME/.local/bin/npm-lite"       "$HOME/.local/bin/go-lite"

rm -rf "$HOME/.local/share/agent-scripts"
```

If the user manually added the repository's `scripts/` directory to a shell
startup file, removal of that PATH line remains a manual step.

### Exit criteria

- [ ] The full repository is available under `~/.local/share/agent-scripts`.
- [ ] Git installation is used when Git is available.
- [ ] Archive fallback works when Git is unavailable.
- [ ] `.agents/skills` is present in both modes.
- [ ] Exactly the four current core commands are symlinked into `~/.local/bin`.
- [ ] All four help commands work after installation.
- [ ] The installer never edits shell configuration.
- [ ] The installer never invokes the Skills CLI.

## Phase 4: Add focused installer tests

Use a temporary `HOME`, controlled `PATH`, and local fixtures or overridable
download/clone sources so tests do not touch the developer's real installation.

### Git installation path

- [ ] With Git available, installer creates a repository checkout under
  `~/.local/share/agent-scripts`.
- [ ] The checkout contains `.git`.
- [ ] The expected repository content and `.agents/skills` are present.
- [ ] Four core symlinks are created in `~/.local/bin`.
- [ ] All four help commands succeed.

### Archive fallback path

- [ ] With Git hidden from `PATH`, installer falls back to `curl` archive
  installation.
- [ ] The resulting directory is still
  `~/.local/share/agent-scripts`.
- [ ] The expected repository content and `.agents/skills` are present.
- [ ] No `.git` directory is expected.
- [ ] Four core symlinks are created in `~/.local/bin`.
- [ ] All four help commands succeed.

### Command-discovery assertions

- [ ] `repo-map commands` includes:
  - `repo-map`
  - `mvn-lite`
  - `npm-lite`
  - `go-lite`
- [ ] A clean installer exposes exactly the four promoted commands through
  `~/.local/bin`:
  - `repo-map`
  - `mvn-lite`
  - `npm-lite`
  - `go-lite`
- [ ] Optionally, with only `~/.local/bin` on `PATH`,
  `repo-map commands --check` reports the four promoted commands as
  available while repository-only tools may remain listed but unavailable.

### PATH assertions

- [ ] When `~/.local/bin` is already on `PATH`, output says the core commands are
  available.
- [ ] When `~/.local/bin` is not on `PATH`, output explains this clearly.
- [ ] Output recommends:

  ```bash
  export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
  ```

- [ ] No shell startup file is created or modified.

### Failure-path assertions

Keep failure testing proportional to the installer:

- [ ] Unsupported OS fails clearly.
- [ ] Missing or invalid archive fails clearly.
- [ ] Archive snapshot missing a core script fails before installation.
- [ ] Syntax-invalid core script fails before installation.
- [ ] Unusable installation target fails clearly.
- [ ] No failure path attempts `sudo`.

Do not add commit-step fault injection, ownership tracking, or rollback-framework
tests.

### Platform validation

- [ ] Run installer smoke tests on Linux.
- [ ] Run installer smoke tests on macOS.
- [ ] Windows remains out of scope.

These may be manual release-validation runs. Adding new CI infrastructure is
not required by issue #3.

## Phase 5: README and release validation

### README positioning

- [ ] Add the Skills badge prominently near the top of the README.
- [ ] State that Agent Scripts provides small command-line tools that make common
  development workflows friendlier to coding agents.
- [ ] Briefly describe the four core tools.
- [ ] Keep Agent Scripts usable independently of AI Badger.

### Installation documentation

Preserve the existing repository-based installation model.

#### Manual Git install

Continue documenting:

```bash
mkdir -p "$HOME/.local/share"
git clone https://github.com/ejboy/agent-scripts.git   "$HOME/.local/share/agent-scripts"

export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Explain that users can add the `export` line to their shell startup file.

#### Simple installer

Add:

```bash
curl -fsSL https://raw.githubusercontent.com/ejboy/agent-scripts/main/install.sh | bash
```

Explain briefly:

- Git is used when available.
- A complete archive snapshot is used when Git is unavailable.
- Four core commands are symlinked into `~/.local/bin`.
- The installer does not edit shell startup files.
- Adding the repository's full `scripts/` directory to `PATH` remains the
  recommended setup for access to all current and future scripts.

### Skill installation documentation

- [ ] Show the conventional Skills installation command.
- [ ] Explain that Skills and command installation are separate.
- [ ] Explain that Node.js/npm is needed only for `npx skills`.
- [ ] Explain that the repository installation contains the Skill definitions
  locally, but the command installer does not invoke the Skills CLI.

### Release validation

Before completing issue #3:

- [ ] Run `shellcheck --severity=warning` on changed shell scripts/tests.
- [ ] Run the full `./tests/test-*.sh` suite.
- [ ] Run `git diff --check`.
- [ ] Test Git-based installation on clean Linux.
- [ ] Test archive fallback on clean Linux.
- [ ] Test installation on clean macOS.
- [ ] Confirm all README commands work exactly as written.
- [ ] Confirm the four Skills are discoverable from the public repository.

## Scope guardrails

Do not add any of the following as part of issue #3:

- a custom Skill installer;
- a `--skills` option in `install.sh`;
- `npx` execution from `install.sh`;
- automatic `.zshrc`, `.bashrc`, `.profile`, or system PATH editing;
- arbitrary writable-PATH-directory scanning;
- GitHub latest-release API resolution;
- downloaded or reconstructed `.git` metadata for archive installs;
- manifests or package-manager state;
- ownership tracking;
- rollback management;
- checksum infrastructure unless a concrete need appears;
- an agent behavioral-evaluation harness;
- new CI infrastructure solely for this installer;
- Windows support;
- new compact modes for npm or Go;
- an AI Badger dependency.

## Final completion checklist

- [ ] `repo-map`, `mvn-lite`, `npm-lite`, and `go-lite` form a coherent promoted
  tool set.
- [ ] `repo-map commands` includes `go-lite`.
- [ ] All four commands expose useful toolchain-independent help.
- [ ] Four conventional Agent Skills exist and are discoverable through
  `npx skills`.
- [ ] README prominently shows Skills support and the Skills badge.
- [ ] Existing manual Git installation remains valid.
- [ ] `curl ... | bash` automates the same repository-based installation model.
- [ ] Git is preferred when available.
- [ ] Complete-repository archive fallback works without Git.
- [ ] Four core commands are symlinked into `~/.local/bin`.
- [ ] The installer never edits shell startup files.
- [ ] The README recommends adding the full `scripts/` directory to `PATH` for
  access to all current and future Agent Scripts.
- [ ] Focused clean-environment installer tests pass.
- [ ] Linux and macOS validation passes.
- [ ] Agent Scripts remains independent of AI Badger.
- [ ] Issue #3 remains focused on distribution and discoverability rather than
  evolving into a package-management project.

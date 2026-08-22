# Installation

## Recommended: simple installer

Run the installer with Bash:

```bash
curl -fsSL https://raw.githubusercontent.com/ejboy/agent-scripts/main/install.sh | bash
```

When Git is available, the installer creates a checkout at
`~/.local/share/agent-scripts`. Without Git, it downloads a complete archive
snapshot to the same location. In both cases it validates the four core
scripts, creates these symlinks in `~/.local/bin`, and leaves shell startup
files unchanged:

- `repo-map`
- `mvn-lite`
- `npm-lite`
- `go-lite`

If `~/.local/bin` is not already on `PATH`, the symlinks still exist but are not
immediately available by name. For all current and future Agent Scripts, add
the full repository scripts directory to `PATH`:

```bash
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add that line to your shell startup file if you want the complete collection in
future sessions. A Git installation can be updated with:

```bash
git -C "$HOME/.local/share/agent-scripts" pull --ff-only
```

An archive installation is updated by rerunning the installer.

## Manual Git installation

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
mkdir -p "$HOME/.local/share"
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file, such as `~/.zshrc` or `~/.bashrc`, to make the tools available in future sessions. Open a new shell afterward, or run the `export` command in the current shell. You can then invoke `mvn-lite`, `npm-lite`, `go-lite`, `html-screenshot`, `launch-browser`, `vscode-test`, and `repo-map` by name from any project.

Verify that the shell can find all seven commands:

```bash
command -v mvn-lite npm-lite go-lite html-screenshot launch-browser vscode-test repo-map
```

### Codex sandbox access for browser and VS Code tools

`vscode-test` and `launch-browser` inspect macOS processes and connect to local DevTools endpoints. `html-screenshot` launches Chrome. When Codex runs these tools inside a restricted sandbox, those operations may be denied even though the underlying application is healthy.

> [!WARNING]
> These tools can launch code, capture the screen, or terminate processes. Use
> narrow command-specific approval rules rather than allowing entire command
> prefixes.

`vscode-test launch` accepts an alternate executable through `--code` and runs extension-under-test code. `html-screenshot` accepts an alternate Chrome executable. Use subcommand-specific rules for `vscode-test`, and require approval for commands that launch code, capture the screen, or terminate processes:

```python
prefix_rule(
    pattern = ["vscode-test", ["status", "inspect", "text", "controls", "wait-control", "activate", "stop"]],
    decision = "allow",
    justification = "Bounded vscode-test operations on a verified managed session need macOS process or localhost access",
)

prefix_rule(
    pattern = ["vscode-test", ["launch", "click", "palette", "screenshot"]],
    decision = "prompt",
    justification = "vscode-test may launch project code or control a desktop process",
)

prefix_rule(
    pattern = ["launch-browser"],
    decision = "prompt",
    justification = "launch-browser starts or stops Chrome outside the sandbox",
)

prefix_rule(
    pattern = ["html-screenshot"],
    decision = "prompt",
    justification = "html-screenshot starts a configurable Chrome executable outside the sandbox",
)
```

Restart Codex after adding the rules. `allow` runs matching commands outside the sandbox without another prompt; `prompt` requires approval for every matching invocation. The internal commands run by these tools do not need separate rules. Do not add equivalent allow rules for `mvn-lite` or `npm-lite`: they intentionally execute project-controlled build scripts and plugins. `repo-map` does not require execution outside the sandbox.

Update the installed tools from the cloned repository:

```bash
git -C ~/.local/share/agent-scripts pull --ff-only
```

## Skills

Skills and command installation are separate. The repository includes the
published `repo-map` and `lite-tools` Skill definitions under [`skills/`](../skills/).
Install them with the Skills CLI when desired:

```bash
npx skills add https://github.com/ejboy/agent-scripts --global --skill repo-map --skill lite-tools
```

Node.js/npm is needed only for `npx skills`. The repository installer does not
invoke `npx` or install Skills automatically.

## Uninstall

Remove the promoted command symlinks and repository:

```bash
rm -f "$HOME/.local/bin/repo-map" \
  "$HOME/.local/bin/mvn-lite" \
  "$HOME/.local/bin/npm-lite" \
  "$HOME/.local/bin/go-lite"
rm -rf "$HOME/.local/share/agent-scripts"
```

If you added the full `scripts/` directory to a shell startup file, remove that
PATH line manually.

## Optional: pin mvn-lite in a project

Shared projects that need a reproducible version can commit a pinned copy of `mvn-lite` at the project root:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/ejboy/agent-scripts/v0.2.0/scripts/mvn-lite \
  -o mvn-lite
chmod +x mvn-lite
./mvn-lite test
```

Commit `mvn-lite` and add `.agent-logs/` to `.gitignore`.

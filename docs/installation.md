# Installation

## Recommended: add the tools to PATH

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
mkdir -p "$HOME/.local/share"
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file, such as `~/.zshrc` or `~/.bashrc`, to make the tools available in future sessions. Open a new shell afterward, or run the `export` command in the current shell. You can then invoke `mvn-lite`, `npm-lite`, `html-screenshot`, `launch-browser`, `vscode-test`, and `repo-map` by name from any project.

Verify that the shell can find all six commands:

```bash
command -v mvn-lite npm-lite html-screenshot launch-browser vscode-test repo-map
```

### Codex sandbox access for browser and VS Code tools

`vscode-test` and `launch-browser` inspect macOS processes and connect to local DevTools endpoints. `html-screenshot` launches Chrome. When Codex runs these tools inside a restricted sandbox, those operations may be denied even though the underlying application is healthy.

Do not allow the entire command prefixes without approval. `vscode-test launch` accepts an alternate executable through `--code` and runs extension-under-test code. `html-screenshot` accepts an alternate Chrome executable. Use subcommand-specific rules for `vscode-test`, and require approval for commands that launch code, control applications, capture the screen, or terminate processes:

```python
prefix_rule(
    pattern = ["vscode-test", ["status", "inspect", "text"]],
    decision = "allow",
    justification = "Read-only vscode-test inspection needs macOS process and localhost DevTools access",
)

prefix_rule(
    pattern = ["vscode-test", ["launch", "activate", "screenshot", "stop"]],
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

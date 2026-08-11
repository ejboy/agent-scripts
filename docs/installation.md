# Installation

## Recommended: add the tools to PATH

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
mkdir -p "$HOME/.local/share"
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file, such as `~/.zshrc` or `~/.bashrc`, to make the tools available in future sessions. Open a new shell afterward, or run the `export` command in the current shell. You can then invoke `mvn-lite`, `npm-lite`, `html-screenshot`, `launch-browser`, and `repo-map` by name from any project.

Verify that the shell can find all five commands:

```bash
command -v mvn-lite npm-lite html-screenshot launch-browser repo-map
```

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

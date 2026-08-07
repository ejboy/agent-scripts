# Installation

## Recommended: add the tools to PATH

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file, such as `~/.zshrc` or `~/.bashrc`, to make the tools available in future sessions. You can then invoke `mvn-lite`, `html-screenshot`, and `launch-browser` by name from any project.

Update the installed tools from the cloned repository:

```bash
git -C ~/.local/share/agent-scripts pull --ff-only
```

## Optional: pin mvn-lite in a project

Shared projects that need a reproducible version can commit a pinned copy of `mvn-lite` at the project root:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/ejboy/agent-scripts/v0.1.0/scripts/mvn-lite \
  -o mvn-lite
chmod +x mvn-lite
./mvn-lite test
```

Commit `mvn-lite` and add `.agent-logs/` to `.gitignore`.

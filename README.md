# agent-scripts

[![Version](https://img.shields.io/badge/version-0.2.0-blue)](https://github.com/ejboy/agent-scripts/tree/v0.2.0)

agent-scripts is a collection of small, local-first command-line utilities for AI-assisted development. Its primary tools, `mvn-lite`, `npm-lite`, and `go-lite`, reduce build and test output noise so agents retain more useful context. Supporting utilities cover browser automation, VS Code extension testing, and local repository discovery. Scripts use predictable command names, work well from PATH, and are designed to be easy for both developers and coding agents to discover and invoke.

## Tools

### Core Build & Test Wrappers

- `mvn-lite` — compact Maven output for builds, tests, and verification runs
- `npm-lite` — compact output for supported npm test and verification workflows (measured output reductions up to 99.99%)
- `go-lite` — compact `go test` output for coding agents

### Browser & Discovery Helpers

- `html-screenshot` — render local HTML or URLs to PNG
- `launch-browser` — launch Chrome with DevTools enabled
- `vscode-test` — compact, approval-friendly VS Code extension testing
- `repo-map` — local repository and agent-capability discovery

See [choosing the right tool](docs/choosing-tools.md) for measured output savings, recommended use cases, and experiment limitations.

Public, standalone utilities live under `scripts/`. Repository release tooling lives
separately under `maintainers/` and is not part of the public utility interface.

## Installation

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
mkdir -p "$HOME/.local/share"
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file to make the tools available in future sessions. You can then invoke the tools under `scripts/` by name from any project.

See the [installation guide](docs/installation.md) for shell setup, updates, and optional project-local pinning.

## mvn-lite

*Introverted Maven for coding agents.*

```bash
mvn-lite clean verify
mvn-lite -pl app -am test
mvn-lite --full dependency:tree
```

See the [`mvn-lite` guide](docs/mvn-lite.md) for options, output behavior,
failure logs, scope, and real-project evidence.

## npm-lite

`npm-lite` reduces successful output for the two supported npm workflows and
direct Node test runs while keeping other invocations unchanged.

```bash
npm-lite run verify
npm-lite run test:unit
npm-lite node --test path/to/test.js
```

See the [`npm-lite` guide](docs/npm-lite.md) for supported commands, count
formats, failure diagnostics, logs, limitations, and experiment evidence.

## go-lite

`go-lite` captures routine `go test` output and reports a compact success line
while retaining complete failure logs. Other Go commands pass through normally.

```bash
go-lite test ./...
go-lite test ./internal/storage
go-lite --full test ./...
```

See the [`go-lite` guide](docs/go-lite.md) for cache behavior, failure logs,
limitations, and sandbox expectations.

## launch-browser

`launch-browser` is a separate macOS utility for starting Google Chrome with DevTools enabled at `http://127.0.0.1:9222`. It defaults to detached headless mode.

```bash
launch-browser
launch-browser --visible
launch-browser --foreground --isolated
launch-browser --stop
launch-browser --help
```

Successful detached launches record their service label and PID in `~/.browser-testing-profile/launch-state`, alongside the existing persistent browser profile. `--stop` validates that the recorded service uses the `xyz.pvrlabs.browser.*` prefix, asks `launchctl` to stop it, and verifies that both the recorded PID and DevTools endpoint have stopped before removing state. If the recorded PID still owns port `9222` after service removal, the script terminates that process directly. It never kills an arbitrary process merely because it uses port `9222`.

The temporary launch log is removed when Chrome exits normally; abnormal-exit logs remain available for diagnostics.

## html-screenshot

`html-screenshot` is a one-shot headless Chrome renderer for local HTML files, `file://` URLs, and HTTP(S) URLs. It does not start or manage a reusable browser instance.

```bash
html-screenshot examples/page.html
html-screenshot --width 1440 --height 900 --wait 1000 -o /tmp/page.png examples/page.html
html-screenshot --scale 2 https://example.com
```

It discovers standard macOS Chrome and Chromium application locations before checking `PATH`. Use `--chrome /path/to/chrome` or `CHROME_BIN=/path/to/chrome` to select an executable explicitly. The default viewport is 1280×720 with a 500 ms virtual-time wait. Successful default output is one line; use `--verbose` to retain Chrome diagnostics. Failed renders always include Chrome diagnostics.

Release maintenance is documented in [maintainers/README.md](maintainers/README.md).

## vscode-test

`vscode-test` provides fixed, reusable operations for macOS VS Code extension testing. Its stable command prefix avoids repeated approvals for changing inline JavaScript, while compact inspection and capped text output reduce transcript noise.

```bash
vscode-test launch --extension-development-path ./extension ./fixture
vscode-test launch --extension-development-path ./extension ./review.code-workspace
vscode-test inspect page
vscode-test inspect panel
vscode-test text panel --limit 2000
vscode-test controls page --filter "AI Badger"
vscode-test click --aria-label "Source Control"
vscode-test palette "AI Badger: Copy Workspace Changes for Review"
vscode-test wait-control --aria-label "AI Badger: Copy Changes for Review" --count 1
vscode-test activate
vscode-test screenshot /tmp/vscode.png
vscode-test stop
```

The launch workspace can be a directory or an existing `.code-workspace` file. The default DevTools port is `9223`. Launch state, profiles, extension storage, and diagnostic logs are kept under `~/.agent-scripts/vscode-test`. Inspection does not accept arbitrary JavaScript: `inspect` emits a one-line JSON summary, `controls` lists visible accessible controls and their enclosing UI context, and `text` normalizes whitespace and defaults to at most 4,000 characters. `click` requires one exact visible aria-label match; `palette` selects one exact command; `wait-control` polls until the exact requested count is rendered. These operations require Node.js 22 or newer. Use `VSCODE_TEST_CODE_BIN` or `launch --code` to select another VS Code executable. `activate` requires managed launch state and focuses its recorded process ID, so it distinguishes test and regular windows from the same application bundle. Codex sandbox setup is documented in [the installation guide](docs/installation.md#codex-sandbox-access-for-browser-and-vs-code-tools).

## repo-map

`repo-map` is a machine-local registry for discovering related repositories and useful commands across projects. Projects should document their required commands directly; coding agents can use `repo-map` to discover additional machine-local capabilities and related repositories.

```bash
repo-map
repo-map command html-screenshot
repo-map commands
repo-map commands --check
repo-map add ~/src/aibadger
repo-map show aibadger
repo-map get aibadger
```

See [choosing the right tool](docs/choosing-tools.md#targeted-repository-discovery) for efficient discovery guidance, registry details, and measured results.

## Status

This is an experimental, small utility collection. `mvn-lite` is not a complete Maven replacement, and this repository is not a build system, browser automation framework, AI agent, or task runner.

MIT licensed; see [LICENSE](LICENSE).

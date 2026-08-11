# agent-scripts

[![Version](https://img.shields.io/badge/version-0.2.0-blue)](https://github.com/ejboy/agent-scripts/tree/v0.2.0)

agent-scripts is a collection of small, local-first command-line utilities for AI-assisted development. Some reduce noisy tool output and save agent context; others make common development tasks easier to automate. Scripts use predictable command names, work well from PATH, and are designed to be easy for both developers and coding agents to discover and invoke.

## Tools

- `mvn-lite` — compact Maven output for builds and tests
- `npm-lite` — compact output for selected npm test and verification workflows
- `html-screenshot` — render local HTML or URLs to PNG
- `launch-browser` — launch Chrome with DevTools enabled
- `repo-map` — local repository and agent-capability discovery

See [choosing the right tool](docs/choosing-tools.md) for measured output savings, recommended use cases, and experiment limitations.

Public, standalone utilities live under `scripts/`. Repository release tooling lives
separately under `maintainers/` and is not part of the public utility interface.

## Installation

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file to make the tools available in future sessions. You can then invoke `mvn-lite`, `npm-lite`, `html-screenshot`, `launch-browser`, and `repo-map` by name from any project.

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

`npm-lite` reduces successful output for the two supported npm workflows while
keeping npm's behavior for every other invocation.

```bash
npm-lite run verify
npm-lite run test:unit
```

See the [`npm-lite` guide](docs/npm-lite.md) for supported commands, count
formats, failure diagnostics, logs, limitations, and experiment evidence.

## launch-browser

`scripts/launch-browser` is a separate macOS utility for starting Google Chrome with DevTools enabled at `http://127.0.0.1:9222`. It defaults to detached headless mode.

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

`scripts/html-screenshot` is a one-shot headless Chrome renderer for local HTML files, `file://` URLs, and HTTP(S) URLs. It does not start or manage a reusable browser instance.

```bash
html-screenshot examples/page.html
html-screenshot --width 1440 --height 900 --wait 1000 -o /tmp/page.png examples/page.html
html-screenshot --scale 2 https://example.com
```

It discovers standard macOS Chrome and Chromium application locations before checking `PATH`. Use `--chrome /path/to/chrome` or `CHROME_BIN=/path/to/chrome` to select an executable explicitly. The default viewport is 1280×720 with a 500 ms virtual-time wait. Successful default output is one line; use `--verbose` to retain Chrome diagnostics. Failed renders always include Chrome diagnostics.

Release maintenance is documented in [maintainers/README.md](maintainers/README.md).

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

# SlopStop

Experimental macOS-only developer workload scanner. The executable is
`experiments/slopstop/slopstop`.

- **Safe to stop:** only Colima when it is running with zero active containers
  on its own runtime. Stop via `colima stop` (`--stop` / `--stop-safe`).
- **Needs review:** conservative allowlist of developer workloads (OpenCode,
  build daemons, dev servers, etc.) using age/CPU/RSS heuristics, plus
  **detached debug browsers** (main Chrome/Chromium/Edge/Brave with
  `--headless` and/or `--remote-debugging-*`) reported immediately with no
  resource gate. Normal interactive browsers and helpers are ignored. Nothing
  under Needs review is ever stopped automatically.

Run `tests/test-slopstop.sh` for deterministic fixture-based tests.

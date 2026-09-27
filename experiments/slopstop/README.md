# SlopStop

Experimental macOS-only developer workload scanner. Not part of the public
`scripts/` interface or repository release tooling. Everything for this
experiment lives in this directory.

Executable: `./slopstop` (from this directory).

## Safe to stop

Only when authoritative idle evidence exists:

| Target | Condition | Stop |
|---|---|---|
| Colima | VM up (`status` is `Running` or omitted — some Colima builds omit it when healthy), zero containers on its own runtime, no k8s/k3s | `colima stop` |
| Gradle | `gradle --status` shows only IDLE daemons | `gradle --stop` |
| mvnd | `mvnd --status` shows only IDLE daemons | `mvnd --stop` |

Use `--stop` (confirm once) or `--stop-safe`. Revalidated immediately before stop.

Kotlin daemons stay **Needs review** unless covered by Gradle status.

## Needs review (never auto-stopped)

- **`python -m http.server`** — age ≥8h only (no CPU/RSS gate); detail includes port (default 8000). Never safe-to-stop.
- Allowlisted workloads (Codex, Claude, OpenCode, other dev servers, JVM daemons not proven idle, …) with **age/CPU/RSS** gates (see thresholds below)
- **Detached debug browsers** — main Chrome/Chromium/Edge/Brave binary with headless and/or remote-debugging flags; **no** age/CPU/RSS gate; helpers and interactive sessions ignored. When SlopStop can associate the browser with a PVR Labs launch-browser job, it prints `kill: launchctl remove <label>`.
- **Docker Desktop / OrbStack** — main app binary only (not backends/helpers); same CPU gates as allowlisted processes, but memory requires **≥8h and ≥2 GiB RSS**. These are resource-based review hints, without a container-idleness check.

### Resource gates (ps heuristic)

| Scope                | Age |     Metric |
| -------------------- | --: | ---------: |
| `python -m http.server` | ≥8h | (none) |
| Allowlisted workload | ≥8h |    CPU ≥5% |
| Allowlisted workload | ≥1h |   CPU ≥20% |
| Allowlisted workload | ≥8h | RSS ≥100 MiB |
| Otherwise-unrecognized current-user process | ≥8h | CPU ≥20% |
| Otherwise-unrecognized current-user process | ≥8h | RSS ≥1 GiB |

The thresholds are hardcoded. The memory rule does not require CPU activity;
age alone does not establish that a process is abandoned. Codex and Claude
recognition covers native executables and canonical Node/Bun invocations with
the package entrypoint immediately after the runtime executable. Runtime options
before the entrypoint are not recognized by this matcher.

Memory matches are labeled `old developer process ≥100 MiB` for recognized workloads
and `old high-memory process` for the generic fallback.

The generic CPU/memory fallback is review-only. It excludes obvious macOS
system services and never makes a process eligible for automatic stopping.

Recognized agent review rows show a Terminal.app label when their TTY matches
any tab, including background tabs. Labels use the tab's custom title when set,
otherwise a neutral `Terminal.app · /dev/ttys…` label. Window names are not used.
If enumerating all tabs fails, the lookup falls back to selected-tab TTYs.
Title lookup failures preserve these mappings. Custom titles require an unchanged
TTY layout after title collection; changes or confirmation failures use neutral labels. The lookup has an approximately two-second
budget; failures and timeouts omit labels. Detached agents do not trigger a lookup.

### Not listed

- **Raw qemu / Virtualization.framework host processes** — deliberately excluded. Host CPU is not an authoritative guest-idle signal, and killing them is not a product-level safe stop. Prefer Colima (or similar) for VM lifecycle.
- Docker/OrbStack helper and backend processes (only the main app binary is considered)
- Interactive browsers without detached-debug flags
- System processes and other users’ processes

## Validation (local to this experiment)

```bash
./test-slopstop.sh
python3 ./test-terminal-labels.py
shellcheck --severity=warning ./slopstop ./test-slopstop.sh
```

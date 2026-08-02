# SlopStop

Experimental macOS-only developer workload scanner. The executable is
`experiments/slopstop/slopstop`.

## Safe to stop

Only when authoritative idle evidence exists:

| Target | Condition | Stop |
|---|---|---|
| Colima | Running, zero containers on its own runtime | `colima stop` |
| Gradle | `gradle --status` shows only IDLE daemons | `gradle --stop` |
| mvnd | `mvnd --status` shows only IDLE daemons | `mvnd --stop` |

Use `--stop` (confirm once) or `--stop-safe`. Revalidated immediately before stop.

Kotlin daemons stay **Needs review** unless covered by Gradle status.

## Needs review (never auto-stopped)

- Allowlisted workloads (OpenCode, dev servers, JVM daemons not proven idle, …) with age/CPU/RSS heuristics
- **Detached debug browsers** (main Chrome/Chromium/Edge/Brave + headless/remote-debugging), no resource gate
- **Docker Desktop / OrbStack** main app processes when running
- **qemu / Virtualization** host processes — host `%CPU` is only a weak hint; guest idle is **not** knowable from outside

## QEMU idle?

**Not authoritatively.** Host low CPU suggests the guest may be quiet, but:

- idle guests can still wake the vCPU
- busy guests almost always show elevated host CPU
- stopping qemu kills the whole VM without app-level drain

So qemu is review-only, with wording like “low host CPU (guest idle unknown)”.

Run `tests/test-slopstop.sh` for deterministic fixture-based tests.

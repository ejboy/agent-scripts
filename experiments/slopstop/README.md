# SlopStop

Experimental macOS-only developer workload scanner. The executable is
`experiments/slopstop/slopstop`; it reports authoritative safe-to-stop resources
and conservative review candidates. Only Colima with zero active containers and
the existing `launch-browser` recorded detached-browser state can be safe.

The browser detector requires the existing state file, a matching Chrome process,
the recorded remote-debugging port, and an inactive recorded launch service. It
uses `launch-browser --stop`, so arbitrary browser processes are never classified
as safe.

Run `tests/test-slopstop.sh` for deterministic fixture-based tests.

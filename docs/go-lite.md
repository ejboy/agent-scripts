# go-lite

`go-lite` is a small wrapper for routine `go test` commands. It keeps normal
test output out of an agent's context while preserving Go's arguments, exit
status, and complete raw failure output.

## Usage

```bash
go-lite test ./...
go-lite test ./internal/storage
go-lite test ./internal/storage -run TestFoo
go-lite test -count=1 ./...
go-lite --full test ./...
go-lite --keep-log test ./...
go-lite --help-go-lite
```

Wrapper options must appear before Go arguments. `--raw` aliases `--full`.
Only the `test` subcommand uses compact mode. Commands such as `go-lite
version`, `go-lite env`, and `go-lite mod tidy` pass directly to `go` with
ordinary output and unchanged arguments.

## Cache behavior

For `go test`, an explicitly configured `GOCACHE` is preserved. If it is not
set, `GO_LITE_CACHE_DIR` is used when nonempty; otherwise the wrapper creates
and uses `/tmp/go-lite-cache`. The precedence is:

1. `GOCACHE`
2. `GO_LITE_CACHE_DIR`
3. `/tmp/go-lite-cache`

The wrapper does not modify `GOMODCACHE`, `GOPATH`, `TMPDIR`, `HOME`, or other
Go environment settings. This cache default only avoids incidental build-cache
writes in a common temporary location; it does not make tests inherently
sandbox-safe. Tests that access networks, Docker, external files, or other
restricted resources may still require approval.

## Output and logs

Compact success output is one line:

```text
PASS · 0 s
```

Successful raw output is discarded unless `--keep-log` is supplied. On
failure, the complete output is retained under `.agent-logs/go/`, and the
wrapper prints the complete output for small failures. Larger failures get a
bounded selection around a few obvious Go failure markers and the final
summary. The retained raw log is authoritative, and the original exit status
is returned unchanged.

Failed `go-lite` logs older than seven days are pruned on later compact runs.
Move a log that must be retained longer. Projects using the wrapper should
ignore `.agent-logs/`.

## Limitations

`go-lite` does not count tests, force `go test -json`, interpret coverage, run
`go vet`, format code, manage packages, or parse every Go diagnostic. Its
failure-context selection is intentionally conservative; use the retained log
or `--full` when the compact diagnostic is insufficient. It only changes
presentation and the default build-cache location, not the behavior or safety
of the underlying tests.

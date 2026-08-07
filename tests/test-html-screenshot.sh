#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/html-screenshot-test.XXXXXX")"
cleanup() {
	rm -rf -- "$test_root"
}
trap cleanup EXIT

bin_dir="$test_root/bin"
fake_chrome="$bin_dir/chromium"
calls="$test_root/chrome-calls"
mkdir -p "$bin_dir"

cat >"$fake_chrome" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$FAKE_CHROME_CALLS"
if [[ "${FAKE_CHROME_MODE:-write}" == fail ]]; then
	printf '%s\n' 'fake Chrome failure' >&2
	exit 9
fi
for arg in "$@"; do
	case "$arg" in
		--screenshot=*) printf '%s\n' png >"${arg#--screenshot=}" ;;
	esac
done
EOF
chmod +x "$fake_chrome"

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

run_renderer() {
	PATH="$bin_dir:/usr/bin:/bin" \
	FAKE_CHROME_CALLS="$calls" \
	"$root/scripts/html-screenshot" --chrome "$fake_chrome" "$@"
}

expected_version="$(<"$root/VERSION")"
output="$(run_renderer --help)"
[[ "$output" == "html-screenshot $expected_version"* ]] || fail_test 'help version heading missing'

html="$test_root/example page.html"
printf '%s\n' '<!doctype html><title>example</title>' >"$html"
output="$(run_renderer --width 800 --height 600 --wait 25 --scale 2 --no-sandbox "$html")"
expected_output="$PWD/example page.png"
[[ "$output" == "Screenshot: $expected_output" ]] || fail_test 'local-file output path was unexpected'
[[ -s "$expected_output" ]] || fail_test 'local-file screenshot was not written'
grep -Fxq -- '--window-size=800,600' "$calls" || fail_test 'width and height were not passed to Chrome'
grep -Fxq -- '--virtual-time-budget=25' "$calls" || fail_test 'wait was not passed to Chrome'
grep -Fxq -- '--force-device-scale-factor=2' "$calls" || fail_test 'scale was not passed to Chrome'
grep -Fxq -- '--no-sandbox' "$calls" || fail_test 'no-sandbox was not passed to Chrome'
expected_url="file://$(cd -- "$(dirname -- "$html")" && pwd)/$(basename -- "$html")"
grep -Fxq "$expected_url" "$calls" || fail_test 'local HTML was not selected as a file URL'
rm -f -- "$expected_output"
output_file="$test_root/output.png"
special_html="$test_root/special #%?.html"
printf '%s\n' '<!doctype html><title>special</title>' >"$special_html"
run_renderer --output "$output_file" "$special_html" >/dev/null
special_url="file://$(cd -- "$(dirname -- "$special_html")" && pwd)/special %23%25%3F.html"
grep -Fxq "$special_url" "$calls" || fail_test 'special filename was not URL-escaped'

output="$(run_renderer --output "$output_file" https://example.test/page)"
normalized_output_file="$(cd -- "$(dirname -- "$output_file")" && pwd)/$(basename -- "$output_file")"
[[ "$output" == "Screenshot: $normalized_output_file" ]] || fail_test 'URL output path was unexpected'
grep -Fxq 'https://example.test/page' "$calls" || fail_test 'HTTP URL was not passed to Chrome'

file_url="file://$(cd -- "$(dirname -- "$html")" && pwd)/$(basename -- "$html")"
run_renderer --output "$output_file" "$file_url" >/dev/null
grep -Fxq "$file_url" "$calls" || fail_test 'file URL was not passed to Chrome'

for args in '--width 0' '--height abc' '--wait -1' '--scale 0'; do
	set +e
	output="$(run_renderer $args https://example.test 2>&1)"
	status=$?
	set -e
	[[ "$status" -eq 1 ]] || fail_test "invalid numeric option succeeded: $args"
	[[ "$output" == *'Error:'* ]] || fail_test "invalid numeric option had no error: $args"
done

set +e
output="$("$root/scripts/html-screenshot" --chrome "$test_root/missing-chrome" https://example.test 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test 'missing Chrome succeeded'
[[ "$output" == *'Chrome or Chromium executable not found'* ]] || fail_test 'missing Chrome error was unclear'

printf '%s\n' stale >"$output_file"
set +e
output="$(FAKE_CHROME_MODE=fail run_renderer --output "$output_file" https://example.test 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test 'failed Chrome render succeeded'
[[ "$(<"$output_file")" == stale ]] || fail_test 'existing screenshot was not restored after Chrome failure'
[[ "$output" == *'Chrome failed to render'* ]] || fail_test 'Chrome failure error was unclear'

printf '%s\n' 'html-screenshot tests passed'

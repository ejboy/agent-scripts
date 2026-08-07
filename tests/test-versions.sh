#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
expected_version="$(<"$root/VERSION")"

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

[[ "$expected_version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
	fail_test "VERSION is not strict major.minor.patch SemVer: $expected_version"

assert_script_version() {
	local script_path="$1"
	local script_name="$2"
	local constant_name="$3"
	local comment_version
	local constant_version

	comment_version="$(sed -n "s/^# $script_name //p" "$script_path")"
	constant_version="$(sed -n "s/^readonly $constant_name=\"\\([^\"]*\\)\"$/\\1/p" "$script_path")"

	[[ "$comment_version" == "$expected_version" ]] ||
		fail_test "$script_name provenance version is '$comment_version', expected '$expected_version'"
	[[ "$constant_version" == "$expected_version" ]] ||
		fail_test "$constant_name is '$constant_version', expected '$expected_version'"
	grep -Fxq '# https://github.com/ejboy/agent-scripts' "$script_path" ||
		fail_test "$script_name provenance URL is missing or incorrect"
}

assert_script_version "$root/scripts/mvn-lite" mvn-lite AGENT_SCRIPTS_VERSION
assert_script_version "$root/scripts/launch-browser" launch-browser AGENT_SCRIPTS_VERSION
assert_script_version "$root/scripts/html-screenshot" html-screenshot AGENT_SCRIPTS_VERSION

grep -Fq "badge/version-$expected_version-blue" "$root/README.md" ||
	fail_test "README version badge does not match VERSION"
grep -Fq "/tree/v$expected_version)" "$root/README.md" ||
	fail_test "README version badge link does not match VERSION"
grep -Fq "/agent-scripts/v$expected_version/scripts/mvn-lite" "$root/README.md" ||
	fail_test "README installation URL does not match VERSION"

printf 'version tests passed (%s)\n' "$expected_version"

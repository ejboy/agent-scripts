#!/usr/bin/env bash
set -uo pipefail

experiment_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="${FINANCIAL_ENGINE_APP_DIR:-}"
agent_scripts_dir="$(cd -- "$experiment_dir/../../../.." && pwd)"
mvn_lite="$agent_scripts_dir/scripts/mvn-lite"

if [[ -z "$project_dir" ]]; then
	printf 'Error: set FINANCIAL_ENGINE_APP_DIR to the Maven project under test\n' >&2
	exit 2
fi

run_and_record() {
	local name="$1"
	shift

	set +e
	"$@" >"$experiment_dir/$name.out" 2>"$experiment_dir/$name.err"
	local status=$?
	set -e
	printf '%s\n' "$status" >"$experiment_dir/$name.status"
	return "$status"
}

(
	cd "$project_dir"
	BUILD_LABEL="common tests" run_and_record baseline ./scripts/mvn -pl common test
)
baseline_status=$?

(
	cd "$project_dir"
	run_and_record mvn-lite "$mvn_lite" -pl common test
)
mvn_lite_status=$?

printf 'baseline_status=%s\nmvn_lite_status=%s\n' \
	"$baseline_status" "$mvn_lite_status"

if ((baseline_status != mvn_lite_status)); then
	exit 1
fi

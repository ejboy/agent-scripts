#!/usr/bin/env bash
set -euo pipefail

if (($# == 0)); then
	printf 'Usage: %s <output-file>...\n' "$0" >&2
	exit 2
fi

printf '%-32s %8s %8s %8s %12s\n' \
	"File" "Bytes" "Words" "Lines" "Est. tokens"

for output_file in "$@"; do
	bytes="$(wc -c <"$output_file")"
	words="$(wc -w <"$output_file")"
	lines="$(wc -l <"$output_file")"
	estimated_tokens="$(((bytes + 3) / 4))"
	printf '%-32s %8d %8d %8d %12d\n' \
		"$(basename "$output_file")" \
		"$bytes" \
		"$words" \
		"$lines" \
		"$estimated_tokens"
done

#!/usr/bin/env bash

set -o errexit -o pipefail
shopt -s nullglob

rm -f /tmp/*hunk*
[ ! -d mod0001____MergedScripts ] || rm mod0001____MergedScripts -rf
./_scripts/find-conflicts.sh | cut -d' ' -f2 | sort -u | while read -r file; do
	[ -n "$file" ] || continue;

	echo ">> Creating merged $file"
	./_scripts/create-merged.sh "$file"
	echo
done

echo '>>> DONE <<<'

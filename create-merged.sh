#!/usr/bin/env bash

set -o errexit -o pipefail

# Given the path of a script file, attempts to automatically merge all scripts from all mods

FILENAME="$1"
MERGE_MOD="mod0001____MergedScripts"
TARGET="$MERGE_MOD/$FILENAME"
LOG="$TARGET.log"
ORIGINAL="../${FILENAME/content/content\/content0}"

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi

# Create the target directory
mkdir -p "$(dirname "$TARGET")"

# Copy over the original file
cp "$ORIGINAL" "$TARGET"
[ -f "$LOG" ] && rm "$LOG"

# Find mods that have a version of this file
for mod in mod*; do
	modfile="$mod/$FILENAME"
	[ -f "$modfile" ] || continue
	[ "$(realpath "$modfile")" == "$(realpath "$TARGET")" ] && continue

	# Skip file if it is blacklisted
	# if grep -Fx "$mod $FILENAME" ./_ignoredfiles > /dev/null 2>&1; then
	# 	echo "> Skipping changes from $mod (blacklisted in _ignoredfiles)"
	# 	continue
	# fi

	# Generate a patch and attempt to apply it, hunk by hunk
	echo "> Trying to apply changes from $mod"
	diff -a -U3 --ignore-blank-lines "$ORIGINAL" "$modfile" > /tmp/patch || [ $? -ne 2 ]
	for i in {1..10000}; do
		# Get the hunk
		filterdiff --hunks="$i" < /tmp/patch > /tmp/hunk
		# If the hunk is empty, we've processed all hunks for this patch, so stop the loop
		[ -s /tmp/hunk ] || break
		# If the hunk already seems to be applied, skip it
		if [[ "$(patch -u --ignore-whitespace --dry-run "$TARGET" < /tmp/hunk 2>&1 || true)" == *'previously applied'* ]]; then
			echo "Hunk #$i skipped (changes are already present)"
			continue
		fi
		# Apply the hunk
		patch -u --ignore-whitespace "$TARGET" < /tmp/hunk | sed "s/Hunk #1/Hunk #$i/g"
	done
	echo "$modfile" >> "$LOG"
done

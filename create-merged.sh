#!/usr/bin/env bash

set -o errexit -o pipefail

# Given the path of a script file, attempts to automatically merge all scripts from all mods

FILENAME="$1"
MERGE_MOD="mod0001____MergedScripts"
TARGET="$MERGE_MOD/$FILENAME"
LOG="$TARGET.log"
ORIGINAL="../${FILENAME/content/content\/content0}"
DIFF_CONTEXT=5

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi

# Create the target directory
mkdir -p "$(dirname "$TARGET")"

# Copy over the original file
cp "$ORIGINAL" "$TARGET"
[ -f "$LOG" ] && rm "$LOG"

applyHunk() {
	# Try to apply the entire hunk
	patch -u --ignore-whitespace "$TARGET" < /tmp/hunk && return 0

	# This failed, so now try to apply it with less context
	nrcl=1 # Number of Removed Context Lines
	while [ $nrcl -le $DIFF_CONTEXT ]; do
		echo "Attempting to apply with less context ($((DIFF_CONTEXT - nrcl)) lines, down from $DIFF_CONTEXT)"
		(
			# Include the filename header lines
			head -n2 /tmp/hunk
			# The patch header with line numbers, changed to be correct
			head -n3 /tmp/hunk | tail -n1 | sed "s/@@ -\\([0-9]\\+\\),\\([0-9]\\+\\) +\\([0-9]\\+\\),\\([0-9]\\+\\) @@/echo \"@@ -\$((\\1+$nrcl)),\$((\\2-$nrcl-$nrcl)) +\$((\\3+$nrcl)),\$((\\4-$nrcl-$nrcl)) @@\"/e"
			# The diff, with n lines cut from the top and bottom
			tail -n+$((4 + nrcl)) /tmp/hunk | head -n-$nrcl
		) > /tmp/partialhunk
		nrcl="$((nrcl + 1))"

		patch -u --ignore-whitespace "$TARGET" < /tmp/partialhunk && return 0
	done

	# None of the attempts succeeded
	return 1
}

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
	diff -a -U$DIFF_CONTEXT --ignore-blank-lines "$ORIGINAL" "$modfile" > /tmp/patch || [ $? -ne 2 ]
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
		applyHunk | sed "s/Hunk #1/Hunk #$i/g"
	done
	echo "$modfile" >> "$LOG"
done

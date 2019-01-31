#!/usr/bin/env bash

set -o errexit -o pipefail
shopt -s nullglob

# Given the path of a script file, attempts to automatically merge all scripts from all mods

FILENAME="$1"
MERGE_MOD="mod0001____MergedScripts"
TARGET="$MERGE_MOD/$FILENAME"
LOG="$TARGET.log"
ORIGINAL="../${FILENAME/content/content\/content0}"
OVERRIDEDIR="_overrides/$FILENAME"
PATCHDIR="_patches/$FILENAME"
DIFF_CONTEXT=5
DIFF_CONTEXT_MIN=2

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi

# Create the target directory
mkdir -p "$(dirname "$TARGET")"

# Copy over the original file
cp "$ORIGINAL" "$TARGET"
[ -f "$LOG" ] && rm "$LOG"

applyPatch() {
	# Split the patch into hunks
	for i in {1..10000}; do
		filterdiff --hunks="$i" < "$1" > /tmp/hunk

		# If the hunk is empty, we've processed all hunks for this patch, so stop the loop
		[ -s /tmp/hunk ] || break

		# Split the hunk into smaller hunks
		for j in {1..10000}; do
			./_scripts/splithunk.py /tmp/hunk $j /tmp/subhunk_

			# If the subhunk is empty, we've processed all subhunks for this hunk, so stop the loop
			[ -s /tmp/subhunk_ ] || break

			# Fix the markings for the subhunk
			rediff /tmp/subhunk_ > /tmp/subhunk

			# Apply the subhunk
			applyHunk /tmp/subhunk | sed "s/Hunk #1/Hunk #$i.$j/g"
		done
	done
}

applyHunk() {
	# Store the hunk by md5
	hash="$(md5sum "$1" | cut -c1-32)"
	cp "$1" "/tmp/_subhunk_$(basename "$ORIGINAL")_$hash"

	# If there is an override for this hunk, use that instead
	overridepath="$OVERRIDEDIR/$hash.patch"
	if [ -f "$overridepath" ]; then
		echo "Hunk #1 is using an override ($overridepath)"
		cp "$overridepath" "$1"
	fi

	# If the hunk already seems to be applied, skip it
	if [[ "$(patch -u --ignore-whitespace --dry-run "$TARGET" < "$1" 2>&1 || true)" == *'previously applied'* ]]; then
		echo "Hunk #1 skipped (changes are already present)"
		return 0
	fi

	# Try to apply the entire hunk
	patch -u --ignore-whitespace "$TARGET" < "$1" && return 0
	return 1

	# This failed, so now try to apply it with less context
	nrcl=1 # Number of Removed Context Lines
	while [ $nrcl -le $((DIFF_CONTEXT - DIFF_CONTEXT_MIN)) ]; do
		echo "Attempting to apply with less context ($((DIFF_CONTEXT - nrcl)) lines, down from $DIFF_CONTEXT)"
		./_scripts/splithunk.py "$1" 1 /tmp/partialhunk_ -c100 -U$((DIFF_CONTEXT - nrcl))
		rediff /tmp/partialhunk_ > /tmp/partialhunk
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
	applyPatch /tmp/patch
done | tee "$LOG"

# Apply extra patches
for patch in "$PATCHDIR"/*.patch; do
	echo "> Applying patch $patch"
	cp "$patch" /tmp/patch
	applyPatch
done | tee -a "$LOG"

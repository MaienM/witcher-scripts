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
PATCH_MAX_FUZZ=6

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi

# Create the target directory
mkdir -p "$(dirname "$TARGET")"

# Copy over the original file
cp "$ORIGINAL" "$TARGET"
[ -f "$LOG" ] && rm "$LOG"

hashHunk() {
	# Ignore the first 3 lines, as changes in filenames, timestamps and/or line numbers are irrelevant
	tail -n+4 < "$1" | md5sum | cut -c1-32
}

makeHashCopy() {
	hash="$(hashHunk "$1")"
	cp "$1" "/tmp/_$(basename "$1")_$(basename "$ORIGINAL")_$hash"
}

doPatchCommand() {
	input="$1"
	shift

	# If the hunk already seems to be applied, skip it
	if [[ "$(patch --dry-run "$@" < "$input" 2>&1 || true)" == *'previously applied'* ]]; then
		echo "Hunk #1 skipped (changes are already present)"
		return 0
	fi

	# Try to apply
	patch --reject-file=- "$@" < "$input"
}

applyPatch() {
	# Split the patch into hunks
	for i in {1..10000}; do
		filterdiff --hunks="$i" < "$1" > /tmp/hunk

		# If the hunk is empty, we've processed all hunks for this patch, so stop the loop
		[ -s /tmp/hunk ] || break

		# Store hunk by hash
		makeHashCopy /tmp/hunk

		# Split the hunk into smaller hunks
		for j in {1..10000}; do
			./_scripts/splithunk.py -c1 -U$DIFF_CONTEXT /tmp/hunk $j /tmp/subhunk_

			# If the subhunk is empty, we've processed all subhunks for this hunk, so stop the loop
			[ -s /tmp/subhunk_ ] || break

			# Fix the markings for the subhunk
			rediff /tmp/subhunk_ > /tmp/subhunk

			# Store subhunk by hash
			makeHashCopy /tmp/subhunk

			# Apply the subhunk
			applyHunk /tmp/subhunk \
				| grep -v '1 out of 1 hunk FAILED' \
				| sed "s/Hunk #1/Hunk #$i.$j/g; s/FAILED/failed with the current settings/g"
		done
	done
}

applyHunk() {
	path="$1"

	# If there is an override for this hunk, use that instead
	hash="$(hashHunk "$1")"
	overridepath="$OVERRIDEDIR/$hash.patch"
	if [ -f "$overridepath" ]; then
		echo "Hunk #1 is using an override ($overridepath)"
		path="$overridepath"
	fi

	# Try to apply the entire hunk
	doPatchCommand "$path" -u --ignore-whitespace "$TARGET" && return 0

	# This failed, so now try to apply it with more fuzz
	fuzz=3 # fuzz factor. default is 2, so no point trying with less
	while [ $fuzz -le $PATCH_MAX_FUZZ ]; do
		echo "Attempting to apply with more fuzz ($fuzz)"
		doPatchCommand "$path" -u --ignore-whitespace "$TARGET" --fuzz=$fuzz && return 0
		fuzz="$((fuzz + 1))"
	done

	# None of the attempts succeeded
	echo "Hunk #1 FAILED COMPLETELY"
	return 1
}

# Find mods that have a version of this file
for mod in mod*; do
	modfile="$mod/$FILENAME"
	[ -f "$modfile" ] || continue
	[ "$(realpath "$modfile")" == "$(realpath "$TARGET")" ] && continue

	# Generate a patch and attempt to apply it, hunk by hunk
	echo "> Trying to apply changes from $mod"
	diff -a -U$DIFF_CONTEXT --ignore-blank-lines "$ORIGINAL" "$modfile" | grep -va 'No newline at end of file' > /tmp/patch || [ $? -ne 2 ]
	applyPatch /tmp/patch
done | tee "$LOG"

# Apply extra patches
for patch in "$PATCHDIR"/*.patch; do
	echo "> Applying patch $patch"
	cp "$patch" /tmp/patch
	applyPatch
done | tee -a "$LOG"

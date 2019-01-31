#!/usr/bin/env bash

set -e

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

	# Generate a patch and attempt to apply it
	echo "> Trying to apply changes from $mod"
	patch -p1 -u -f "$TARGET" <(diff -a -U3 "$ORIGINAL" "$modfile" | tee /tmp/patch)
	echo "$modfile" >> "$LOG"
done

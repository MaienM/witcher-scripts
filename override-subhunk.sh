#!/usr/bin/env bash

# Check the passed subhunk exists, and is actually a subhunk (as opposed to a patch or hunk, which cannot be overridden)
SUBHUNK="$1"
if [ ! -f "$SUBHUNK" ]; then
	echo >&2 "Cannot find subhunk ($SUBHUNK)"
	exit 1
fi
if [[ $SUBHUNK =~ /tmp/_subhunk_*.ws_* ]]; then
	echo >&2 "The passed file doesn't appear to be a subhunk ($SUBHUNK)"
	exit 1
fi

# Get the patch directory path by inspecting the first line of the diff, which refers to the original file
OVERRIDEDIR="$(head -n1 < "$SUBHUNK" | tr '\t' ' ' | cut -d' ' -f2 | sed 's#../content/content0/#_overrides/content/#')"
mkdir -p "$OVERRIDEDIR"

# Extract the hash from the filename, and determine the override location using it
HASH="${SUBHUNK/*.ws_}"
OVERRIDEPATH="$OVERRIDEDIR/$HASH.patch"

# Create a copy of the original, for future reference
cp "$SUBHUNK" "$OVERRIDEPATH.orig"

# Copy over the original patch and edit it
cp "$SUBHUNK" "$OVERRIDEPATH.tmp"
"$EDITOR" "$OVERRIDEPATH.tmp"
rediff "$OVERRIDEPATH.tmp" > "$OVERRIDEPATH"
rm "$OVERRIDEPATH.tmp"

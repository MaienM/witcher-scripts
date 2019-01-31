#!/usr/bin/env bash

FILENAME="$1"
MODNAME="$2"

# If a filename of a file in a mod was passed, split it up
if [[ -z "$MODNAME" && $FILENAME =~ mod* ]]; then
	MODNAME="$(echo "$FILENAME" | cut -d/ -f1)"
	FILENAME="$(echo "$FILENAME" | cut -d/ -f2-)"
fi

DIFF_CONTEXT="${DIFF_CONTEXT:5}"
ORIGINAL="../${FILENAME/content/content\/content0}"
MODIFIED="${MODNAME}/$FILENAME"

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi
if [ ! -f "$MODIFIED" ]; then
	echo >&2 "Cannot find modified script ($MODIFIED)"
	exit 1
fi

diff -a -U5 --ignore-blank-lines --ignore-all-space --ignore-tab-expansion "$ORIGINAL" "$MODIFIED"

#!/usr/bin/env bash

FILENAME="$1"
MOD1NAME="$2"
MOD2NAME="$2"
ORIGINAL="../${FILENAME/content/content\/content0}"
MODIFIED1="${MOD1NAME}/$FILENAME"
MODIFIED2="${MOD2NAME}/$FILENAME"

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi
if [ ! -f "$MODIFIED1" ]; then
	echo >&2 "Cannot find modified script ($MODIFIED1)"
	exit 1
fi
if [ ! -f "$MODIFIED2" ]; then
	echo >&2 "Cannot find modified script ($MODIFIED2)"
	exit 1
fi

nvim -d "$MODIFIED1" "$ORIGINAL" "$MODIFIED2"

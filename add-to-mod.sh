#1/usr/bin/env sh

FILENAME="$1"
MODNAME="$2"
ORIGINAL="../${FILENAME/content/content\/content0}"
MODIFIED="${MODNAME}/$FILENAME"

if [ ! -f "$ORIGINAL" ]; then
	echo >&2 "Cannot find original script ($ORIGINAL)"
	exit 1
fi
if [ ! -d "$MODNAME" ]; then
	echo >&2 "Cannot find mod ($MODNAME)"
	exit 1
fi
if [ -f "$MODIFIED" ]; then
	echo >&2 "File already exists in mod ($MODIFIED)"
	exit 1
fi

mkdir -p "$(dirname "$MODIFIED")"
cp "$ORIGINAL" "$MODIFIED"

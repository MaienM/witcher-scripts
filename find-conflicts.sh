#!/usr/bin/env sh

find . -path '*scripts*' -name '*.ws' | sed 's@^./\([^/]*\)/\(.*\)$@\1 \2@' | sort -k2 | uniq -f1 --all-repeated=separate

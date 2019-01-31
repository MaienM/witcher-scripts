#!/usr/bin/env sh

for fn in $(rg -a --encoding=utf-16 -l "$2" "/tmp/_subhunk_$1_"*); do
	cat "$fn"
	echo ">>> $fn"
	read -r
done

#!/usr/bin/env python3

import argparse
import sys


def isdiffline(line):
	return line.startswith(b'-') or line.startswith(b'+')


def main(args):
	parser = argparse.ArgumentParser(description = 'Split hunks')
	parser.add_argument('file', type=argparse.FileType('rb'))
	parser.add_argument('hunk', type=int)
	parser.add_argument('output', type=argparse.FileType('wb'))
	parser.add_argument(
		'-c',
		'--context',
		type = int,
		default = 2,
		help = 'The amount of context lines allowed inside a hunk before a new hunk is started.',
	)
	parser.add_argument(
		'-u',
		'-U',
		'--unified',
		type = int,
		default = 10000,
		help = 'The max amount of context lines to keep around each hunk.',
	)
	args = parser.parse_args(args)

	# Split off the header lines
	headerlines = []
	headerlines.append(args.file.readline())
	headerlines.append(args.file.readline())
	headerlines.append(args.file.readline())

	# Read the rest of the lines
	lines = args.file.read().split(b'\n')

	# Create groups of context/non-context lines
	grouped = [[]]
	group = grouped[0]
	groupisdiff = False
	for line in lines:
		isdiff = isdiffline(line)
		if isdiff != groupisdiff:
			group = []
			grouped.append(group)
			groupisdiff = isdiff
		group.append(line)

	# Ensure the first and last group are context
	if isdiffline(grouped[0][0]):
		grouped.insert(0, [])
	if isdiffline(grouped[-1][0]):
		grouped.append([])

	# Merge non-context groups that are separated by too few context lines to be split
	tomerge = []
	for i, group in enumerate(grouped):
		isdiff = i % 2 == 1 # even groups are context, odd are diffs
		isfirstorlast = i == 0 or i == len(grouped) - 1
		if len(group) <= args.context and not isdiff and not isfirstorlast:
			tomerge.append(i)
	for i in reversed(tomerge):
		grouped[i-1:i+2] = [sum(grouped[i-1:i+2], [])]

	# If the requested hunk doesn't exist, stop now
	hunkindex = args.hunk * 2 - 1
	if hunkindex < 0 or hunkindex >= len(grouped):
		return

	# Print the result, which is the header + context before + diff + context after
	args.output.write(b''.join(headerlines))
	outputlines = []
	outputlines += grouped[hunkindex - 1][-args.unified:]
	outputlines += grouped[hunkindex]
	outputlines += grouped[hunkindex + 1][:args.unified]
	outputlines.append(b'')
	args.output.write(b'\n'.join(outputlines))


if __name__ == '__main__':
	main(sys.argv[1:])

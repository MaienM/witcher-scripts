#!/usr/bin/env python3

import argparse
import sys

from pprint import pprint


def isdiffline(line):
	return not isheaderline(line) and (line.startswith(b'-') or line.startswith(b'+'))


def isheaderline(line):
	return line.startswith(b'---') or line.startswith(b'+++') or line.startswith(b'@@')


def group_by(collection, condition):
	"""
	Group a collection into smaller collections based on a given condition.

	Each consecutive grouping of items that yield the same result for the condition will be put into the same
	collection. As soon as an item yield a different result a new collection will be started.

	>>> group_by([1, 2, 4, 6, 5, 4, 2, 7, 5, 9, 1], lambda n: n % 2 == 0)
	[[1], [2, 4, 6], [5], [4, 2], [7, 5, 9, 1]]
	"""
	grouped = []
	group = None
	previous_result = None
	for item in collection:
		result = condition(item)
		if result != previous_result:
			group = []
			grouped.append(group)
			previous_result = result
		group.append(item)
	return grouped


def process_hunk(args, headerlines, datalines):
	# Create groups of context/non-context lines
	grouped = group_by(datalines, isdiffline)

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

	# Build new subhunks, each with their own (invalid) header
	subhunks = []
	for i in range(1, len(grouped), 2):
		subhunk = []
		subhunk += headerlines
		subhunk += grouped[i - 1][-args.unified:]
		subhunk += grouped[i]
		subhunk += grouped[i + 1][:args.unified]
		subhunks.append(subhunk)
	return subhunks


def main(args):
	parser = argparse.ArgumentParser(description = 'Split hunks')
	parser.add_argument('file', type = argparse.FileType('rb'))
	parser.add_argument('outputpath')
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

	# Read the file, grouping the lines into hunk headers & data
	lines = list(args.file)
	# lines = [line[:20] for line in lines]
	sharedheaderlines = lines[:2]
	lines = group_by(lines[2:], isheaderline)

	# Process the read hunks one by one, splitting them into sub-hunks
	hunks = []
	while lines:
		hunks.append(process_hunk(args, sharedheaderlines + lines.pop(0), lines.pop(0)))

	# Write each subhunk to a numbered file
	for hi, hunk in enumerate(hunks):
		for shi, subhunk in enumerate(hunk):
			with open(f'{args.outputpath}_{hi + 1}_{shi + 1}', 'wb') as f:
				f.write(b''.join(subhunk))


if __name__ == '__main__':
	main(sys.argv[1:])

= Witcher 3 mod scripts

I made these scripts because the Script Merger that most people use does not play nice with Wine, while the game itself
does.

The main script is `fix-all-conflicts.sh`. In the majority of the cases, simply running this will resolve all conflicts
between all mods.

If for whatever reason this fails, you will need to manually intervene. Find out where the problem is (usually you will
have a complition error when starting the game telling you where to look). You can then use `find-subhunk.sh` to find
the hunk that failed to apply properly, and then you can use `create-override.sh` to create an override for this hunk
that fixes the problem. Some knowledge of diffs/patch files will be required.

One thing to keep in mind is that the files of the witcher are in UTF-16, but the output of diff is not. This means that
the diff files will be a mixture of UTF-8 and UTF-16. Depending on your editor, this may or may not be handled well. If
it is not, it is often easier to do the following:

- Open the automatically merged file (in `mod0001____MergedScripts`) (I'll be calling this `automerge.ws`)
- Apply the failed hunk manually (leaving in the failed version as well)
- Save to a different name (I'll be using `patched.ws` in this example)
- Run the following: `diff -a automerge.ws patched.ws` to get the override for this hunk

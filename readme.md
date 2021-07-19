# TROUBLESHOOTER: Abandoned Children - DateMine

This repo contains scripts which can be used to convert the ``pack`` structure of the game [TROUBLESHOOTER: Abandoned Children](https://store.steampowered.com/app/470310/TROUBLESHOOTER_Abandoned_Children/) into the ``original`` and readable data structure used by the devs.
That means, that there are readable file paths and that nearly all files are reusable. Some files are encrypted and won't be extracted.
While it's possible to bypass the protection, out of respect for the developers, I won't share how to bypass it nor the files themselves.

## Scripts

Python 3.5+ is required to run the scripts.

You have to clone/copy this repo into the Troubleshooter main folder
e.g. ``Steam\steamapps\common\Troubleshooter\TROUBLESHOOTER-mine``
or adjust the GAME folder in ``path.py``.

* extract_files.py - uses index.xml to restore the data structure
* extract_imagesets.py - splits the extracted imagesets into its single images
* index_dumper.py - used to extract the index.xml from the game

## script & xml Folders

The content of these two folders is encrypted,
but they are necessary to create a wiki or similar content.
That's why they are shared here.
(They developers haven't disagreed with that ~~yet~~.)

## index.xml

This file lists all game assets with their original path, package path and virtual path (in zips).
It's the bridge that is neceassry to restore the original data structure from the package structure every normal user has.

The original index.xml is encrypted, but you can use ``index_dumper.py`` to dump the decrypted version from the game itself.
This can be done with the following steps:

1. start index_dumper.py
2. use mode 0 - ``memory size log``
3. enter 100000000 as break size
4. open Process Monitor
5. start the game and exit it once it reachs the start screen
6. in Process Monitor, look for the exact time when the game opend package/index
7. open log.txt and search for that time - copy the memory size used at that time (static for some entries)
8. start index_dumper.py again
9. use mode 1 - ``index.xml extraction``
10. enter the copied memory size as break size
11. run the game again
12. now you should have the latest index.xml in the folder

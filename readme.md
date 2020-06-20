# TROUBLESHOOTER: Abandoned Children - DateMine

This repo contains scripts which can be used to convert the packet structure of the game [TROUBLESHOOTER: Abandoned Children](https://store.steampowered.com/app/470310/TROUBLESHOOTER_Abandoned_Children/) into the original and readabke data structure used by the devs.
That means, that there are readable file paths and that nearly all files are reusable. Some files are encrypted and won't be extracted.
While it's possible to bypass the protection, out of respect for the developers, I won't share how to bypass it nor the files themselves.

## Scripts

Python 3.5+ is required to run the scripts.
You have to copy both scripts and the ``index.html`` to the main dir of the game and execute the scripts there.
(So in ``\TROUBLESHOOTER Abandoned Children\`` and not in any of its subfolders.)

* extract_files.py - uses index.html to restore the data structure
* extract_imagesets.py - splits the imagesets into its single images

## index.html

The file ``index.html`` is used by the game to figure out the location of the files in the packet structure and how to load them.
The original file is encrypted (``Package\index``) but it's quite easy to get the decrypted version,
so I will share it here. ~~And well, without it it wouldn't be possible to restore the original data structure. ~~

# TROUBLESHOOTER: Abandoned Children - DateMine

This repo contains scripts that can be used to convert the ``pack`` structure of the game [TROUBLESHOOTER: Abandoned Children](https://store.steampowered.com/app/470310/TROUBLESHOOTER_Abandoned_Children/) into the ``original`` and readable data structure used by the devs.

## Scripts

Python 3.5+ is required to run the scripts.

You have to clone/copy this repo into the Troubleshooter main folder
e.g. ``Steam\steamapps\common\Troubleshooter\TROUBLESHOOTER-mine``
or adjust the GAME folder in ``path.py``.

* ~~extract_files.py - uses index.xml to restore the data structure~~
* extract_files_troublecrypt.py - decrypts the index, restores the original data structure, and decrypts all encrypted files
* extract_imagesets.py - splits the extracted image sets into its single images
* index_dumper.py - used to extract the index.xml from the game

## Troublecrypt.exe

It's a small cli tool that makes it possible to decrypt the encrypted files of the game.
It can also encrypt files again, which can be used to create mods.
Since the devs encrypted their assets for whatever reason and might use the encryption for their network protocols as well, I won't publicize the code of this tool nor how the encryption works.

[VirusTotal 0/89](https://www.virustotal.com/gui/url/837ec474b84ae6d360b47b61d704fc542963f65a9b2d49b3a55ddc26d8e353da/detection)

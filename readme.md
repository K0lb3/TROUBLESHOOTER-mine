# TROUBLESHOOTER: Abandoned Children - DateMine

This repo contains scripts that can be used to convert the ``pack`` structure of the game [TROUBLESHOOTER: Abandoned Children](https://store.steampowered.com/app/470310/TROUBLESHOOTER_Abandoned_Children/) into the ``original`` and readable data structure used by the devs.

## Scripts

Python 3.5+ is required to run the scripts.
The ``pillow`` module is required for the ``extract_imagesets`` script.
You can install it via
``pip install pillow``
or
``python -m pip install pillow``


You have to clone/copy this repo into the Troubleshooter main folder
e.g. ``Steam\steamapps\common\Troubleshooter\TROUBLESHOOTER-mine``
or adjust the GAME folder in ``path.py``.

* extract_files.py - decrypts, unpacks and copies the "pack"ed files into the "Data" directory using the original file paths and names
* extract_imagesets.py - splits the extracted image sets into its single images


## Troublecrypt.exe

It's a small cli tool that makes it possible to decrypt the encrypted files of the game.
It can also encrypt files again, which can be used to create mods.
Since the devs encrypted their assets for whatever reason and might use the encryption for their network protocols as well, I won't publicize the code of this tool nor how the encryption works.

[VirusTotal 0/89](https://www.virustotal.com/gui/url/837ec474b84ae6d360b47b61d704fc542963f65a9b2d49b3a55ddc26d8e353da/detection)


## Troublecrypt.DLL (64bit)

Same as for the exe, just that it can be integrated into other tools as library.
It exports two functions,
```c
int decrypt(char* data, long size);
int encrypt(char* data, long size);
```
which do what their name says.

Note that the data should have a length multiple of 16,
as otherwise the encryption will fail.
The EXE/CLI versions automatically padds 0es at the end,
the dll doesn't do so.


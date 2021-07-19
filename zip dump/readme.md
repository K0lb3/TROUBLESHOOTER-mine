Troubleshooter uses [libzip](https://github.com/nih-at/libzip) to decompress the zip files.

The encrypted zip files are pretty much as the name suggests, zip files that are encrypted afterwards.

That means, that after the files are decrypted, they are processed like a normal zip.

We can abuse this fact by modifying the libzip libary, so that it dumps all files from all zips that are opened with it. That way, when the game opens the zip after decryption, our modified libary will dump the content of the formerly encrypted zips.

The unencrypted zip files are opened as file, while the encrypted zip files are opened from memory, as they are decrypted in memory, so by modifying the [zip_open_from_source function](https://github.com/nih-at/libzip/blob/184ddda3d0a7f9a17c5ce0dd117d38eb48fa7ca9/lib/zip_open.c#L79) our modified lib will only dump the content of encrypted zips and not of the normal ones.


You can find a compiled version of a modified libzip library within the [build dir](https://github.com/K0lb3/TROUBLESHOOTER-mine/tree/master/zip_dump/build),
if you want to compile it yourself, download libzip and add the intercept function as done in the [zip_open.c](https://github.com/K0lb3/TROUBLESHOOTER-mine/tree/master/zip_dump/zip_open.c) in this dir.
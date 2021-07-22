import os, shutil, zipfile
from PIL import Image
import xml.etree.ElementTree as ET
import subprocess
import ctypes
import io


# import re
from path import LOCAL, PACK, DATA

TROUBLECRYPT = os.path.join(LOCAL, "troublecrypt.exe")
# copy or extract files
def main():
    # 1. update index.xml in pack
    index_fp = os.path.join(DATA, "index.xml")
    troublecrypt_cli(os.path.join(PACK, "index"), index_fp)
    # fix index.xml ending
    with open(index_fp, "r+") as f:
        end = f.seek(0, 2)
        f.seek(end - 16)
        data = f.read(16)
        f.truncate(end - (16 - len(data.rstrip("\x00"))))
    # parse index.xml
    tree = ET.parse(index_fp)
    root = tree.getroot()
    # manual parse because of invalid path of some entries
    # reItem = re.compile(r' (\w+?)="(.+?)"')
    # root = [
    #    {match[1]: match[2] for match in reItem.finditer(line)}
    #    for line in open(index_fp, "rt", encoding="utf8", errors="replace")
    #    .read()
    #    .split("\n")
    #    if len(line) > 9
    # ]
    for item in root:
        src = os.path.join(PACK, *item.get("pack").split("/"))
        dst = os.path.join(DATA, *item.get("original").split("\\"))

        dsize = os.path.getsize(dst) if os.path.exists(dst) else -1
        if dsize == int(item.get("size")):
            continue
        print(dst)
        os.makedirs(os.path.dirname(dst), exist_ok=True)

        PROCESS[item.get("method")](src, dst, item)


def process_raw(src, dst, item):
    shutil.copy(src, dst)


def process_zip(src, dst, item):
    try:
        z = zipfile.ZipFile(src)
        with open(dst, "wb") as f:
            f.write(z.open(item.get("virtual")).read())
        z.close()
    except zipfile.BadZipFile:
        return


def process_encrypted_zip(src, dst, item):
    virtual = item.get("virtual")

    if _dll:
        with open(src, "rb") as f:
            data = f.read()
        _dll.decrypt(data, len(data))
        zip_inp = io.BytesIO(data)
    else:
        zip_inp = os.path.join(os.environ["TEMP"], virtual)
        troublecrypt_cli(os.path.join(PACK, *item.get("pack").split("/")), zip_inp)
    try:
        z = zipfile.ZipFile(zip_inp)
        with open(dst, "wb") as f:
            f.write(z.open(item.get("virtual")).read())
        z.close()
    except zipfile.BadZipFile:
        return

    if _dll:
        zip_inp.close()
    else:
        os.unlink(zip_inp)


def troublecrypt_cli(src, dst, enc="dec"):
    subprocess.call([TROUBLECRYPT, enc, src, dst])


_dll = None
try:
    _dll = ctypes.WinDLL(os.path.join(LOCAL, "troublecrypt.dll"))
except:
    pass


PROCESS = {
    "raw": process_raw,
    "zip": process_zip,
    "encrypted_zip": process_encrypted_zip,
}

if __name__ == "__main__":
    main()

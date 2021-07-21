import os, shutil, zipfile
from PIL import Image
#import xml.etree.ElementTree as ET
import re
from path import LOCAL, PACK, DATA
import subprocess
import io

TROUBLECRYPT = os.path.join(LOCAL, "troublecrypt.exe")
# copy or extract files
def main():
    # 1. update index.xml in pack
    index_fp = os.path.join(DATA, "index.xml")
    troublecrypt(
        os.path.join(PACK, "index"),
        index_fp
    )
    # manual parse because of invalid path of some entries
    reItem = re.compile(r' (\w+?)="(.+?)"')
    root = [{match[1]:match[2] for match in reItem.finditer(line)} for line in open(index_fp, "rt", encoding="utf8", errors="replace").read().split("\n") if len(line)>9]
    for item in root:
        src = os.path.join(PACK, *item.get("pack").split("/"))
        dst = os.path.join(DATA, *item.get("original").split("\\"))

        dsize = os.path.getsize(dst) if os.path.exists(dst) else -1
        if dsize == int(item.get("size")) or dsize == 0:
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


DUMP_FILES = os.listdir(LOCAL)

def process_encrypted_zip(src, dst, item):
    virtual = item.get("virtual")
    zip_fp = os.path.join(os.environ["TEMP"], virtual)
    
    troublecrypt(
        os.path.join(PACK, *item.get("pack").split("/")),
        zip_fp
    )

    try:
        z = zipfile.ZipFile(zip_fp)
        with open(dst, "wb") as f:
            f.write(z.open(item.get("virtual")).read())
        z.close()
    except zipfile.BadZipFile:
        return
    
    os.unlink(zip_fp)

def troublecrypt(src: str, dst: str, enc = "dec"):
    subprocess.call([TROUBLECRYPT, enc, src, dst])


PROCESS = {
    "raw": process_raw,
    "zip": process_zip,
    "encrypted_zip": process_encrypted_zip,
}

if __name__ == "__main__":
    main()

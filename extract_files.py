import os, shutil, zipfile
from PIL import Image
#import xml.etree.ElementTree as ET
import re
from path import DUMP, LOCAL, PACK, DATA

# copy or extract files
def main():
    index_path = os.path.join(LOCAL, "index.xml")
    #root = ET.parse(index_path).getroot()

    # manual parse because of invalid path of some entries
    reItem = re.compile(r' (\w+?)="(.+?)"')
    root = [{match[1]:match[2] for match in reItem.finditer(line)} for line in open(index_path, "rt", encoding="utf8", errors="replace").read().split("\n") if len(line)>9]
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
    except zipfile.BadZipFile:
        return


DUMP_FILES = os.listdir(DUMP)

def process_encrypted_zip(src, dst, item):
    virtual = item.get("virtual")
    if virtual in DUMP_FILES:
        src = os.path.join(DUMP, virtual)
        shutil.copy(src, dst)
        print("New encrypted", dst)
        if os.path.exists(dst + "(encrypted)"):
            os.unlink(dst + "(encrypted)")
    else:
        with open(dst, "wb") as f:
            pass


PROCESS = {
    "raw": process_raw,
    "zip": process_zip,
    "encrypted_zip": process_encrypted_zip,
}

if __name__ == "__main__":
    main()

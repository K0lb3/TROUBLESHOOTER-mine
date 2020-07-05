import os, shutil, zipfile
from PIL import Image
import xml.etree.ElementTree as ET

from path import LOCAL, PACK, DATA

# copy or extract files
def main():
    tree = ET.parse(os.path.join(LOCAL, "index.xml"))
    for item in tree.getroot():
        src = os.path.join(PACK, *item.get("pack").split("/"))
        dst = os.path.join(DATA, *item.get("original").split("\\"))

        if os.path.exists(dst) and os.path.getsize(src) == item.get("size"):
            continue
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


def process_encrypted_zip(src, dst, item):
    # create dummy file
    with open(dst, "wb") as f:
        pass


PROCESS = {
    "raw": process_raw,
    "zip": process_zip,
    "encrypted_zip": process_encrypted_zip,
}

if __name__ == "__main__":
    main()

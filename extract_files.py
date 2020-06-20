import os, shutil, zipfile
from PIL import Image
import xml.etree.ElementTree as ET

# set dirs
ROOT = os.path.dirname(os.path.realpath(__file__))
PACK = os.path.join(ROOT, "Package")
DATA = os.path.join(ROOT, "Data")

# copy or extract files
def main():
    tree = ET.parse(os.path.join(ROOT, "index.xml"))
    for item in tree.getroot():
        src = os.path.join(PACK, *item.get("pack").split("/"))
        dst = os.path.join(DATA, *item.get("original").split("\\"))

        if os.path.exists(dst) and os.path.getsize(src) == item.get("size"):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)

        method = item.get("method")
        if method == "raw":
            shutil.copy(src, dst)
        elif method == "zip":
            try:
                z = zipfile.ZipFile(src)
                with open(dst, "wb") as f:
                    f.write(z.open(item.get("virtual")).read())
            except zipfile.BadZipFile:
                continue
        elif method == "encrypted_zip":
            # create dummy file
            dst += "(encrypted)"
            with open(dst, "wb") as f:
                pass
        print(dst)


if __name__ == "__main__":
    main()

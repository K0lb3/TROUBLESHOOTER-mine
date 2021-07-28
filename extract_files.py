import os
import xml.etree.ElementTree as ET
from lib.paths import PACK, DATA
from lib.crypt import decrypt, extract


def main():
    os.makedirs(DATA, exist_ok=True)
    # 1. update index.xml in pack
    index_fp = os.path.join(DATA, "index.xml")
    decrypt(os.path.join(PACK, "index"), index_fp)
    # fix index.xml ending
    with open(index_fp, "r+") as f:
        end = f.seek(0, 2)
        f.seek(end - 16)
        data = f.read(16)
        f.truncate(end - (16 - len(data.rstrip("\x00"))))
    # parse index.xml
    tree = ET.parse(index_fp)
    root = tree.getroot()

    for item in root:
        src = os.path.join(PACK, *item.get("pack").split("/"))
        dst = os.path.join(DATA, *item.get("original").split("\\"))

        dsize = os.path.getsize(dst) if os.path.exists(dst) else -1
        if dsize == int(item.get("size")):
            continue
        print(dst)
        extract(src, dst, item)


if __name__ == "__main__":
    main()

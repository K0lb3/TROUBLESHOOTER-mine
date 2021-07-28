import os
import xml.etree.ElementTree as ET
from lib.paths import PACK, MOD, BACKUP
from lib.crypt import encrypt, decrypt, pack, extract
from shutil import copy
import io


def main():
    # os.makedirs(OVERRIDE, exist_ok=True)
    os.makedirs(BACKUP, exist_ok=True)
    # 1. load original xml
    index_fp = os.path.join(PACK, "index.xml")
    ori_index_fp = os.path.join(PACK, "index")
    raw_xml = decrypt(ori_index_fp).rstrip(b"\00")
    # parse index.xml
    tree = ET.parse(io.BytesIO(raw_xml))
    root = tree.getroot()

    item_map = {item.get("original"): item for item in root}

    # pack mod files
    for root, dirs, files in os.walk(MOD):
        for fp in files:
            fp = os.path.join(root, fp)
            ifp = fp[len(MOD) + 1 :]
            item = item_map.get(ifp, None)

            if item != None:
                pack_path = os.path.join(PACK, *item.get("pack").split("/"))
                backup_path = os.path.join(BACKUP, *item.get("pack").split("/"))
                os.makedirs(os.path.dirname(backup_path), exist_ok=True)
                # only create a backup if the file size fits, otherwise the backup might be replaced by an old mod
                if os.path.getsize(pack_path) == item.get("csize"
                ) and (not os.path.exists(backup_path) or os.path.getsize(backup_path) != item.get("csize")):
                    copy(pack_path, backup_path)
                pack(fp, pack_path, item)
                # item.set("pack", f"..\\{os.path.basename(OVERRIDE)}\\{item.get('pack')}")
                print("Packed", ifp)
            else:
                print("Couldn't find", ifp, "in the original index.")
                print("Import of new assets isn't implemented yet.")

    # save index
    # copy(ori_index_fp, os.path.join(BACKUP, "index"))


if __name__ == "__main__":
    main()

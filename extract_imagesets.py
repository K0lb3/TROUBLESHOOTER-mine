import os
from PIL import Image
import xml.etree.ElementTree as ET

from path import DATA


def handle_imageset(xml, delete_src=True):
    # parse xml
    root = ET.parse(xml).getroot()

    # get local path
    folder = os.path.dirname(xml)

    # get img
    img_path = os.path.join(folder, root.get("imagefile"))
    if not os.path.exists(img_path):
        print("Image not found:", img_path)
        return
    print("Unpack", img_path)
    img = Image.open(img_path)

    # set dst path
    dst = os.path.join(folder, root.get("name"))
    os.makedirs(dst, exist_ok=True)
    print(dst)

    # extract sprites
    for item in root:
        name = item.get("name")
        x = int(item.get("xPos"))
        y = int(item.get("yPos"))
        w = int(item.get("width"))
        h = int(item.get("height"))
        fp = os.path.join(dst, f"{name}.png")
        img.crop((x, y, x + w, y + h)).save(fp)

    # clean-up
    if delete_src:
        os.unlink(xml)
        os.unlink(img_path)


if __name__ == "__main__":
    for root, _, files in os.walk(DATA):
        for f in files:
            if f.endswith(".imageset"):
                handle_imageset(os.path.join(root, f))


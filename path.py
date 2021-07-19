import os

# path of the game
GAME = r"E:\Program Files (x86)\Steam\steamapps\common\Troubleshooter"

# source dirs
PACK = os.path.join(GAME, "Package")
DUMP = os.path.join(GAME, "Release","bin","zip_dump")

# extract dirs
LOCAL = os.path.dirname(os.path.realpath(__file__))
ROOT = os.path.dirname(LOCAL)
DATA = os.path.join(ROOT, "Original")

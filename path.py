import os

LOCAL = os.path.dirname(os.path.realpath(__file__))
ROOT = os.path.dirname(LOCAL)

# path of the game
GAME = r"E:\Program Files (x86)\Steam\steamapps\common\Troubleshooter"
# in case the path isn't configured, assume that the scripts are in a sub-dir of the Troubleshooter dir
if not os.path.exists(GAME):
    GAME = os.path.dirname(ROOT)

# source dirs
PACK = os.path.join(GAME, "Package")
DUMP = os.path.join(GAME, "Release","bin","zip_dump")

# extract dir - where the data will be copied to
DATA = os.path.join(ROOT, "Original")
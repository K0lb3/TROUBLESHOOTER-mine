import os

LIB = os.path.dirname(os.path.realpath(__file__))
LOCAL = os.path.dirname(LIB)
ROOT = os.path.dirname(LOCAL)

# path of the game
GAME = r"E:\Program Files (x86)\Steam\steamapps\common\Troubleshooter"
# in case the path isn't configured, assume that the scripts are in a sub-dir of the Troubleshooter dir
if not os.path.exists(GAME):
    GAME = ROOT

# source dirs
PACK = os.path.join(GAME, "Package")
if not os.path.exists(PACK):
    print("Couldn't find the Package folder.")
    print("Path: ", PACK)
    print("Please move the directory holding the scripts to a directory within the Troubleshooter folder")
    print("or set the GAME path in path.py, please note to add a r before the path or replace all \\ with \\\\.")


# extract dir - where the data will be copied to
DATA = os.path.join(ROOT, "Data") # can be set to another path, e.g. r"D:\TroubleCrypt\Data"

# unpacked mod data - still has to be packed
MOD = os.path.join(GAME, "Mod")
# packed mod data used by the game - don't edit this one for now
# OVERRIDE = os.path.join(GAME, "Override")
# backup of the original files
BACKUP = os.path.join(GAME, "BackUp")

# path of troublecrypt
TROUBLECRYPT_EXE = os.path.join(LIB, "troublecrypt.exe")
TROUBLECRYPT_LIB = os.path.join(LIB, "troublecrypt.dll")
from zipfile import ZipFile, BadZipFile
from shutil import copy
from .paths import TROUBLECRYPT_LIB, TROUBLECRYPT_EXE
import ctypes
import os
import subprocess
import tempfile
import io
from typing import Union

def extract(src: str, dst: str, item):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    method = item.get("method")
    if method == "raw":
        extract_raw(src, dst, item)
    elif method == "zip":
        extract_zip(src, dst, item)
    elif method == "encrypted_zip":
        extract_encrypted_zip(src, dst, item)


def pack(src: str, dst: str, item):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    method = item.get("method")
    if method == "raw":
        pack_raw(src, dst, item)
    elif method == "zip":
        pack_zip(src, dst, item)
    elif method == "encrypted_zip":
        pack_encrypted_zip(src, dst, item)


def extract_raw(src: str, dst: str, item):
    copy(src, dst)


def pack_raw(src: str, dst: str, item):
    copy(src, dst)


def extract_zip(src: str, dst: str, item):
    try:
        z = ZipFile(src)
        with open(dst, "wb") as f:
            f.write(z.open(item.get("virtual")).read())
        z.close()
    except BadZipFile:
        return


def pack_zip(src: str, dst: str, item):
    try:
        z = ZipFile(dst, "w")
        z.write(src, item.get("virtual"))
        z.close()
    except BadZipFile:
        return


def extract_encrypted_zip(src: str, dst: str, item):
    virtual = item.get("virtual")

    data = decrypt(src)
    zip_inp = io.BytesIO(data)

    try:
        z = ZipFile(zip_inp)
        with open(dst, "wb") as f:
            f.write(z.open(item.get("virtual")).read())
        z.close()
    except BadZipFile:
        return


def pack_encrypted_zip(src: str, dst: str, item):
    virtual = item.get("virtual")

    with open(src, "rb") as f:
        data = f.read()
    
    f = io.BytesIO()
    z = ZipFile(f, "w")
    z.writestr(item.get("virtual"), data)
    z.close()
    f.seek(0)
    encrypt(f.read(), dst)


def decrypt(src: Union[str, bytes], dst: str = None) -> Union[None, bytes]:
    if _dll:
        if isinstance(src, str):
            with open(src, "rb") as f:
                data = f.read()
        else:
            data = src

        _dll.decrypt(data, len(data))

        if dst:
            with open(dst, "wb") as f:
                f.write(data)
        else:
            return data
    else:
        sub_src = src
        if isinstance(src, (bytes, bytearray)):
            sub_src = tempfile.mkstemp()[1]
            with open(sub_src, "wb") as f:
                f.write(src)

        sub_dst = dst if dst else tempfile.mkstemp()[1]

        subprocess.call([TROUBLECRYPT_EXE, "dec", sub_src, sub_dst])

        #if isinstance(src, (bytes, bytearray)):
        #    os.unlink(sub_src)

        if dst:
            pass
        else:
            with open(sub_dst, "rb") as f:
                data = f.read()
            #os.unlink(sub_dst)
            return data


def encrypt(src: Union[str, bytes], dst: str = None) -> Union[None, bytes]:
    if _dll:
        if isinstance(src, str):
            with open(src, "rb") as f:
                data = f.read()
        else:
            data = src

        pad = len(data)%16
        if pad:
            data += b"\x00" * (16 - pad)

        _dll.encrypt(data, len(data))

        if dst:
            with open(dst, "wb") as f:
                f.write(data)
        else:
            return data
    else:
        sub_src = src
        if isinstance(src, (bytes, bytearray)):
            sub_src = tempfile.mkstemp()[1]
            with open(sub_src, "wb") as f:
                f.write(src)
                pad = len(src)%16
                if pad:
                    f.write(b"\x00" * (16 - pad))

        sub_dst = dst if dst else tempfile.mkstemp()[1]

        subprocess.call([TROUBLECRYPT_EXE, "enc", sub_src, sub_dst])

        #if isinstance(src, (bytes, bytearray)):
        #    os.unlink(sub_src)

        if dst:
            pass
        else:
            with open(sub_dst, "rb") as f:
                data = f.read()
            #os.unlink(sub_dst)
            return data


_dll = None
try:
    _dll = ctypes.WinDLL(TROUBLECRYPT_LIB)
except:
    pass

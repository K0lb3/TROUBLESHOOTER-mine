import win32security, win32con, win32api, win32file, win32process, ctypes
import re
import psutil
import os

dbghelp = ctypes.windll.dbghelp


def main():
    # FIGURE OUT THE BREAK FILE SIZE

    mode = input("""Mode Selection:
    0 - memory size log
    1 - index.xml extraction
    """)
    
    mode = int(mode)
    
    break_size = int(input("Break Size (Bytes): "))
    d = Dumper("ProtoLion.exe")
    fp = "ProtoLion.dmp"

    #break_size = 82944000
    last_size = 0
    if mode == 0:
        from datetime import datetime
        states = []
        log = []
        while True:
            mem = d.memory_info["WorkingSetSize"]
            if (mem == last_size) and mem not in states:
                log.append("%s - %d" % (str(datetime.now()), mem))
                states.append(mem)

                # since the break size can increase if the target increases in size,
                # we stop when the programm stopped processing the target, so when the size stays the same
                # compare the timestamps in the produced log with the load log from Process Monitor
                if mem > break_size:
                    break
            last_size = mem

        open("log.txt", "wt", encoding="utf8").write("\n".join(log))

    # DUMP MEMORY AT CORRECT POINT
    else:
        while True:
            mem = d.memory_info["WorkingSetSize"]
            # since the break size can increase if the target increases in size,
            # we stop when the programm stopped processing the target, so when the size stays the same
            if mem > break_size and mem == last_size:
                break
            last_size = mem

        d.create_mini_dump(fp)

        # extract index
        with open(fp, "rb") as f:
            data = f.read()

        index = re.search(b"(<index>.+?</index>)", data, flags=re.S)

        if index:
            with open("index.xml", "wb") as f:
                f.write(index[0])
            os.unlink(fp)
        else:
            input("Failed to extract the index.xml")


class MINIDUMP_TYPES_CLASS(object):
    """
    MINIDUMP types
    """

    MiniDumpNormal = 0x00000000
    MiniDumpWithDataSegs = 0x00000001
    MiniDumpWithFullMemory = 0x00000002
    MiniDumpWithHandleData = 0x00000004
    MiniDumpFilterMemory = 0x00000008
    MiniDumpScanMemory = 0x00000010
    MiniDumpWithUnloadedModules = 0x00000020
    MiniDumpWithIndirectlyReferencedMemory = 0x00000040
    MiniDumpFilterModulePaths = 0x00000080
    MiniDumpWithProcessThreadData = 0x00000100
    MiniDumpWithPrivateReadWriteMemory = 0x00000200
    MiniDumpWithoutOptionalData = 0x00000400
    MiniDumpWithFullMemoryInfo = 0x00000800
    MiniDumpWithThreadInfo = 0x00001000
    MiniDumpWithCodeSegs = 0x00002000


def adjustPrivilege(priv):
    flags = win32security.TOKEN_ADJUST_PRIVILEGES | win32security.TOKEN_QUERY
    htoken = win32security.OpenProcessToken(win32api.GetCurrentProcess(), flags)
    id = win32security.LookupPrivilegeValue(None, priv)
    newPrivileges = [(id, win32security.SE_PRIVILEGE_ENABLED)]
    win32security.AdjustTokenPrivileges(htoken, 0, newPrivileges)


class Dumper:
    def __init__(self, name="", pid=-1):
        if pid == -1:
            pid = self.get_process_id(name)
        self.pid = pid
        while True:
            try:
                self.phandle = win32api.OpenProcess(
                    win32con.PROCESS_VM_READ | win32con.PROCESS_QUERY_INFORMATION,
                    0,
                    pid,
                )
                break
            except:
                pass

    def get_process_id(self, name):
        while True:
            for x in psutil.process_iter():
                if x.name() == name:
                    return x.pid

    @property
    def memory_info(self):
        return win32process.GetProcessMemoryInfo(self.phandle)

    def create_mini_dump(self, file_name):
        if os.path.exists(file_name):
            os.unlink(file_name)
        # Adjust privileges.
        # adjustPrivilege(win32security.SE_DEBUG_NAME)
        adjustPrivilege("seDebugPrivilege")
        # pHandle = win32api.OpenProcess(
        #             win32con.PROCESS_VM_READ | win32con.PROCESS_QUERY_INFORMATION,
        #             0, pid)

        # print( 'pHandle Status: ', win32api.FormatMessage(win32api.GetLastError()))
        fHandle = win32file.CreateFile(
            file_name,
            win32file.GENERIC_READ | win32file.GENERIC_WRITE,
            win32file.FILE_SHARE_READ | win32file.FILE_SHARE_WRITE,
            None,
            win32file.CREATE_ALWAYS,
            win32file.FILE_ATTRIBUTE_NORMAL,
            None,
        )

        # print( 'fHandle Status: ', win32api.FormatMessage(win32api.GetLastError()))
        success = dbghelp.MiniDumpWriteDump(
            self.phandle.handle,  # Process handle
            self.pid,  # Process ID
            fHandle.handle,  # File handle
            MINIDUMP_TYPES_CLASS.MiniDumpWithFullMemory,  # Dump type - MiniDumpNormal
            None,  # Exception parameter
            None,  # User stream parameter
            None,  # Callback parameter
        )

        # print( 'MiniDump Status: ', win32api.FormatMessage(win32api.GetLastError()))
        return success


if __name__ == "__main__":
    main()

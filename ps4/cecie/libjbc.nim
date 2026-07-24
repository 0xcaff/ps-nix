type JbcCred* {.bycopy.} = object
  uid*: uint32
  ruid*: uint32
  svuid*: uint32
  rgid*: uint32
  svgid*: uint32
  prison*: uint
  cdir*: uint
  rdir*: uint
  jdir*: uint
  sceProcType*: uint64
  sonyCred*: uint64
  sceProcCap*: uint64

proc jbcGetCred(cred: ptr JbcCred): cint {.
  cdecl,
  importc: "jbc_get_cred",
  header: "libjbc.h"
.}

proc jbcSetCred(cred: ptr JbcCred): cint {.
  cdecl,
  importc: "jbc_set_cred",
  header: "libjbc.h"
.}

proc jbcMountInSandbox(systemPath, mountName: cstring): cint {.
  cdecl,
  importc: "jbc_mount_in_sandbox",
  header: "libjbc.h"
.}

proc jbcUnmountInSandbox(mountName: cstring): cint {.
  cdecl,
  importc: "jbc_unmount_in_sandbox",
  header: "libjbc.h"
.}

proc get_cred*(): JbcCred =
  discard jbcGetCred(result.addr)

proc set_cred*(cred: JbcCred): cint =
  var mutableCred = cred
  jbcSetCred(mutableCred.addr)

proc sudo_mount*(systemPath, mountName: string): cint =
  jbcMountInSandbox(systemPath.cstring, mountName.cstring)

proc sudo_unmount*(mountName: string): cint =
  jbcUnmountInSandbox(mountName.cstring)

import posix

const
  EncSealedKeyLen = 0x60
  DecSealedKeyLen = 0x20
  IoctlBufferLen = 0x100

proc ioctl(fd: cint, request: culong, argp: pointer): cint {.
  cdecl,
  importc,
  header: "<sys/ioctl.h>"
.}

proc generateSealedKey*(sealedKey: var array[EncSealedKeyLen, byte]): cint =
  # The PS4 driver writes beyond the nominal 0x60-byte key.  The original
  # binding deliberately put a 0x30-byte dummy buffer after this one; use a
  # larger explicit buffer so stack protection remains valid.
  var data: array[IoctlBufferLen, byte]
  let fd = open("/dev/sbl_srv", O_RDWR)
  if fd == -1:
    return -1

  result = ioctl(fd, culong(0x40845303), data.addr)
  if result == 0:
    copyMem(sealedKey.addr, data.addr, EncSealedKeyLen)
  discard close(fd)

proc decryptSealedKey*(
  sealedKey: array[EncSealedKeyLen, byte],
  decryptedKey: var array[DecSealedKeyLen, byte]
): cint =
  var data: array[IoctlBufferLen, byte]
  copyMem(data.addr, sealedKey.unsafeAddr, EncSealedKeyLen)

  let fd = open("/dev/sbl_srv", O_RDWR)
  if fd == -1:
    return -1

  result = ioctl(fd, culong(0xC0845302), data.addr)
  if result == 0:
    copyMem(decryptedKey.addr, data[EncSealedKeyLen].addr, DecSealedKeyLen)
  discard close(fd)

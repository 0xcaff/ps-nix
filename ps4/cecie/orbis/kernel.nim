proc sceKernelDlsym*(
  handle: cint,
  symbol: cstring,
  address: ptr pointer
): cint {.cdecl, importc, header: "<orbis/libkernel.h>".}

proc sceKernelLoadStartModule*(
  moduleFileName: cstring,
  args: csize_t,
  argp: pointer,
  flags: uint32,
  opt: pointer,
  result: pointer
): cint {.cdecl, importc, header: "<orbis/libkernel.h>".}

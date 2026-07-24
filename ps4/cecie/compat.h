#pragma once

#include <stddef.h>

/*
 * OpenOrbis's bits/alltypes.h declares mode_t as unsigned int before its
 * PS4-specific unsigned-short declaration.  The kernel's struct stat ABI uses
 * the latter; the wider type shifts st_size from 0x48 to 0x50, so Cecie reads
 * st_blocks as the file size.  Predeclare the PS4 ABI type before sys/types.h.
 */
#ifndef __DEFINED_mode_t
typedef unsigned short mode_t;
#define __DEFINED_mode_t
#endif

#include <sys/types.h>

int sendfile(
  int fd,
  int socket,
  off_t offset,
  size_t nbytes,
  void *headers,
  off_t *bytes_sent,
  int flags
);

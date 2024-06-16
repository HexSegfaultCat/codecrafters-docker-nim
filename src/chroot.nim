import std/[posix]

proc chroot(path: cstring): cint {.importc: "chroot", header: "<unistd.h>".}


type ChrootStatus* = enum
  Ok                    = 0,
  PermissionDenied      = EACCES,       ## Search permission is denied on a component of the path prefix.
  BadAddress            = EFAULT,       ## `path` points outside your accessible address space.
  InputOutputError      = EIO,          ## An I/O error occurred.
  TooManySymbolicLinks  = ELOOP,        ## Too many symbolic links were encountered in resolving `path`.
  NameTooLong           = ENAMETOOLONG, ## `path` is too long.
  NoEntry               = ENOENT,       ## The file does not exist.
  OutOfMemory           = ENOMEM,       ## Insufficient kernel memory was available.
  NotDirectory          = ENOTDIR,      ## A component of `path` is not a directory.
  OperationNotPermitted = EPERM,        ## The caller has insufficient privilege.


proc changeRoot*(path: string): ChrootStatus =
  let status = chroot(path.cstring)
  if status == 0:
    return Ok
  else:
    return cast[ChrootStatus](errno)

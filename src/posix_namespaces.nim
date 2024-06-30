import std/posix

{.emit:"""/*INCLUDESECTION*/
#define _GNU_SOURCE
""".}

proc chroot(path: cstring): cint {.importc: "chroot", header: "<unistd.h>".}
proc unshare(flags: cint): cint {.importc: "unshare", header: "<sched.h>"}

type ErrorStatus* = enum
  Ok                    = 0,
  OperationNotPermitted = EPERM,        ## The caller has insufficient privilege.
  NoEntry               = ENOENT,       ## The file does not exist.
  InputOutputError      = EIO,          ## An I/O error occurred.
  OutOfMemory           = ENOMEM,       ## Insufficient kernel memory was available.
  PermissionDenied      = EACCES,       ## Search permission is denied on a component of the path prefix.
  BadAddress            = EFAULT,       ## `path` points outside your accessible address space.
  NotDirectory          = ENOTDIR,      ## A component of `path` is not a directory.
  InvalidBit            = EINVAL,       ## An invalid bit was specified in `flags`.
  NameTooLong           = ENAMETOOLONG, ## `path` is too long.
  TooManySymbolicLinks  = ELOOP,        ## Too many symbolic links were encountered in resolving `path`.

proc changeRoot*(path: string): ErrorStatus =
  let status = chroot(path.cstring)
  if status == 0:
    return Ok
  else:
    return cast[ErrorStatus](errno)

type UnshareFlag* {.size: sizeof(cint).} = enum
  #CLONE_VM* = 0x00000100'i32
  #CLONE_FS* = 0x00000200'i32
  #CLONE_FILES* = 0x00000400'i32
  #CLONE_SIGHAND* = 0x00000800'i32
  #CLONE_PIDFD* = 0x00001000'i32
  #CLONE_PTRACE* = 0x00002000'i32
  #CLONE_VFORK* = 0x00004000'i32
  #CLONE_PARENT* = 0x00008000'i32
  #CLONE_THREAD* = 0x00010000'i32
  CloneNewNamespace = 0x00020000'i32,
  #CLONE_SYSVSEM* = 0x00040000'i32
  #CLONE_SETTLS* = 0x00080000'i32
  #CLONE_PARENT_SETTID* = 0x00100000'i32
  #CLONE_CHILD_CLEARTID* = 0x00200000'i32
  #CLONE_DETACHED* = 0x00400000'i32
  #CLONE_UNTRACED* = 0x00800000'i32
  #CLONE_CHILD_SETTID* = 0x01000000'i32
  CloneNewControlGroup = 0x02000000'i32,
  #CLONE_NEWUTS* = 0x04000000'i32
  CloneNewIpc = 0x08000000'i32,
  CloneNewUser =  0x10000000'i32,
  CloneNewPid = 0x20000000'i32,
  CloneNewNet = 0x40000000'i32,
  #CLONE_IO* = 0x80000000'i32

proc unshareProcess*(flags: seq[UnshareFlag]): ErrorStatus =
  var flagsValue: cint = 0
  for flag in flags:
    flagsValue = flagsValue or cast[cint](flag)

  let status = unshare(flagsValue)
  if status == 0:
    return ErrorStatus.Ok
  else:
    return cast[ErrorStatus](errno)


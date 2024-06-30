import std/[os, osproc, streams]
import std/[strformat, strutils]
from strtabs import StringTableRef;

import posix_namespaces, dockerhub, utils

proc runProcess*(
  stdOutHandle: File,
  stdErrorHandle: File,
  chrootPath: string,
  command: string,
  args: openArray[string] = [],
  workingDir: string = "",
  env: StringTableRef = nil,
  options: set[osproc.ProcessOption] = {},
): int =
  let unshareStatus = unshareProcess(@[CloneNewPid, CloneNewUser, CloneNewIpc])
  if unshareStatus != Ok:
    raise newException(IOError, fmt"Unable to call unshare {unshareStatus}")

  let chrootStatus = changeRoot(chrootPath)
  if chrootStatus != Ok:
    raise newException(IOError, fmt"Unable to call chroot {chrootStatus}")

  var p = startProcess(
    command = command,
    workingDir = workingDir,
    args = args,
    env = env,
    options = options
  )
  defer: close(p)

  let stdoutStream = outputStream(p)
  let stderrStream = errorStream(p)

  var buffer {.noinit.}: array[256, char]

  while running(p):
    while stdoutStream.atEnd() == false:
      let readBytes = stdoutStream.readData(addr buffer, buffer.len)
      discard stdOutHandle.writeBuffer(addr buffer, readBytes)

    while stderrStream.atEnd() == false:
      let readBytes = stderrStream.readData(addr buffer, buffer.len)
      discard stdErrorHandle.writeBuffer(addr buffer, readBytes)

  stdOutHandle.flushFile()
  stdErrorHandle.flushFile()

  return p.peekExitCode()

proc dockerRun*(containerName, image, command: string, args: varargs[string]): int =
  let imageParts = image.split(':')

  let imageName = imageParts[0]
  let imageVersion = if imageParts.len > 1: imageParts[1] else: "latest"
  let fullImage = imageName & ":" & imageVersion

  let containerPath = ContainersPath/containerName
  if not os.dirExists(containerPath):
    let imagePath = ImagesPath/(fullImage & ".tar.gz")
    if not os.fileExists(imagePath):
      fetchImage(imageName, imageVersion)

    createDir(containerPath)
    discard execProcess(
      command = "tar",
      args = ["-xf", imagePath, "-C", containerPath], # TODO: Use `--overwrite` for multi-layer images
      options = {poUsePath, poStdErrToStdOut},
    )
    copyDockerExplorerBinaryIfExists(containerPath)

  let exitCode = runProcess(
    stdOutHandle = stdout,
    stdErrorHandle = stderr,
    chrootPath = containerPath,
    command = command,
    args = args,
  )
  return exitCode

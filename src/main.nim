# Usage: your_docker.sh run <image> <command> <arg1> <arg2> ...

import osproc, streams

from os import commandLineParams
from strtabs import StringTableRef;


proc runProcess*(
  stdOutHandle: File,
  stdErrorHandle: File,
  command: string,
  args: openArray[string] = [],
  workingDir: string = "",
  env: StringTableRef = nil,
  options: set[osproc.ProcessOption] = {},
): int =
  var p = startProcess(
    command,
    workingDir = workingDir,
    args = args,
    env = env,
    options = options
  )
  defer: close(p)

  let stdoutStream = outputStream(p)
  let stderrStream = errorStream(p)

  var buffer: array[256, char]

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


when isMainModule:
  let command = commandLineParams()[2]
  let args = commandLineParams()[3..^1]

  let exitCode = runProcess(stdout, stderr, command, args)
  quit(exitCode)

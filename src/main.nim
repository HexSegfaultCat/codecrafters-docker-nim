# Usage: your_docker.sh run <image> <command> <arg1> <arg2> ...

import std/[os, times]

import container

when isMainModule:
  let params = commandLineParams()

  let dockerCommand = params[0]
  if dockerCommand != "run":
    echo "Unknown or unsupported command " & dockerCommand
    quit(1)

  let image = params[1]
  let command = params[2]
  let args = params[3..^1]

  let timestamp = getTime().format("yyyyMMddHHmmssfffffffff")
  let uniqueContainerName = image & "-" & timestamp

  let exitCode = dockerRun(
    containerName = uniqueContainerName,
    image,
    command,
    args,
  )
  quit(exitCode)


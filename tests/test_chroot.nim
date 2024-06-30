import unittest
import shared/utils

import std/strutils

import container, dockerhub

test "try to access /home in chroot":
  var outBuffer: array[1024, cchar]
  var errBuffer: array[1024, cchar]

  var memStdOut = memOpen(addr outBuffer, outBuffer.len.uint, "w")
  defer: memStdOut.close()

  var memStdErr = memOpen(addr errBuffer, errBuffer.len.uint, "w")
  defer: memStdErr.close()

  let exitCode = runProcess(
    stdOutHandle = memStdOut,
    stdErrorHandle = memStdErr,
    chrootPath = ContainersPath & "/codecrafters-docker-explorer",
    command = "/usr/local/bin/docker-explorer",
    args = ["ls", "/home"],
  )
  check exitCode == 2

  let outputMessage = $cast[cstring](addr outBuffer[0])
  check outputMessage.startsWith("No such file or directory")


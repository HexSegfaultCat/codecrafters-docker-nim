import unittest
import std/strutils

import shared/utils

import main


test "pid must be 1":
  var outBuffer: array[1024, cchar]
  var errBuffer: array[1024, cchar]

  var memStdOut = memOpen(addr outBuffer, outBuffer.len.uint, "w")
  defer: memStdOut.close()

  var memStdErr = memOpen(addr errBuffer, errBuffer.len.uint, "w")
  defer: memStdErr.close()

  let exitCode = runProcess(
    memStdOut,
    memStdErr,
    "./chroot",
    "/usr/local/bin/docker-explorer",
    ["mypid"]
  )
  check exitCode == 0
  check cast[cstring](addr outBuffer[0]) == "1\n"


import unittest

import shared/utils

import main


test "redirect to stderr":
  var outBuffer: array[1024, cchar]
  var errBuffer: array[1024, cchar]

  var memStdOut = memOpen(addr outBuffer, outBuffer.len.uint, "w")
  defer: memStdOut.close()

  var memStdErr = memOpen(addr errBuffer, errBuffer.len.uint, "w")
  defer: memStdErr.close()

  const errorMessage = "Some random message"
  let exitCode = runProcess(
    memStdOut,
    memStdErr,
    "./chroot",
    "/usr/local/bin/docker-explorer",
    ["echo_stderr", errorMessage]
  )
  check exitCode == 0
  check cast[cstring](addr outBuffer[0]) == ""
  check cast[cstring](addr errBuffer[0]) == errorMessage & "\n"


test "redirect to stdout":
  var outBuffer: array[1024, cchar]
  var errBuffer: array[1024, cchar]

  var memStdOut = memOpen(addr outBuffer, outBuffer.len.uint, "w")
  defer: memStdOut.close()

  var memStdErr = memOpen(addr errBuffer, errBuffer.len.uint, "w")
  defer: memStdErr.close()

  const standardMessage = "Standard message"
  let exitCode = runProcess(
    memStdOut,
    memStdErr,
    "./chroot",
    "/usr/local/bin/docker-explorer",
    ["echo", standardMessage]
  )
  check exitCode == 0
  check cast[cstring](addr outBuffer[0]) == standardMessage & "\n"
  check cast[cstring](addr errBuffer[0]) == ""


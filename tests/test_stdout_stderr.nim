import unittest

import main

proc memOpen(restrict: pointer, len: csize_t, modes: cstring): File {.
  importc: "fmemopen",
  header: "<stdio.h>"
.}

test "Redirect to stderr":
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
    "/usr/local/bin/docker-explorer",
    ["echo_stderr", errorMessage]
  )
  check exitCode == 0
  check cast[cstring](addr outBuffer[0]) == ""
  check cast[cstring](addr errBuffer[0]) == errorMessage & "\n"

test "Redirect to stdout":
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
    "/usr/local/bin/docker-explorer",
    ["echo", standardMessage]
  )
  check exitCode == 0
  check cast[cstring](addr outBuffer[0]) == standardMessage & "\n"
  check cast[cstring](addr errBuffer[0]) == ""


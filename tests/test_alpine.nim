import unittest

import container

test "example busybox container":
  let exitCode = dockerRun(
    containerName = "example-alpine",
    image = "alpine",
    command = "/bin/echo",
    args = "hello from busybox",
  )
  check exitCode == 0


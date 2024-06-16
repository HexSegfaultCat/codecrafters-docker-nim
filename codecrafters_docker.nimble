# Package

version       = "0.1.0"
author        = "HexSegfaultCat"
description   = "CodeCrafters: Build your own Docker"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["codecrafters_docker"]


# Dependencies

# CodeCrafters uses very old version of Nim
requires "nim >= 1.0.6"

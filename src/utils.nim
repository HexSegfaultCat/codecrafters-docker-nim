import std/os

proc getArchitecture*(): string {.compileTime.} =
  when defined x86:
    return "x86"
  elif defined amd64:
    return "amd64"
  else:
    raise newException(IOError, "Unknown CPU architecture")

proc copyDockerExplorerBinaryIfExists*(containerPath: string): void = 
  const localBinPath = "/usr/local/bin"
  const fullFilePath = localBinPath/"/docker-explorer"

  createDir(containerPath/localBinPath)
  try:
    copyFileWithPermissions(fullFilePath, containerPath/fullFilePath)
  except:
    echo "DockerExplorer binary not found in " & localBinPath

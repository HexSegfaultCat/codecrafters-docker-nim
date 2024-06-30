import std/[os, osproc]
import std/[httpclient, streams]
import std/[strformat, strutils]
import std/[json] # FIX: Add `jsonutils`
import std/[options, tables, sequtils]

import utils

const
  RuntimeDataPath = "./runtime-data"
  ContainersPath* = RuntimeDataPath & "/containers"
  ImagesPath* = RuntimeDataPath & "/images"

const AuthUrl = (
  "https://auth.docker.io/token" &
  "?service=registry.docker.io" &
  "&scope=repository:library/$1:pull"
)

const ManifestUrl = (
  "https://registry.hub.docker.com/v2/" &
  "library/$1/manifests/$2"
)

const LayerUrl = (
  "https://registry.hub.docker.com/v2/" &
  "library/$1/blobs/$2"
)

type DockerAuthResponse* = object # ref object
  token*: string
  access_token*: string
  expires_in*: Option[int]
  issued_at*: Option[string]
  refresh_token*: Option[string]

type
  PlatformItem = object # ref object
    architecture*: string
    os*: string
    `os.version`*: Option[string]
    `os.features`*: Option[seq[string]]
    variant*: Option[string]
    features*: Option[seq[string]]

  ManifesetItem = object # ref object
    annotations*: Option[Table[string, string]] # Option[TableRef[string, string]]
    mediaType*: string
    digest*: string
    size*: int
    platform*: PlatformItem

  LayerItem = object # ref object
    mediaType*: string
    digest*: string
    size*: int

  ConfigItem = object # ref object
    mediaType*: string
    digest*: string
    size*: int

type
  ManifestMetadataResponse = object # ref object
    schemaVersion*: int
    mediaType*: string
    manifests*: seq[ManifesetItem]

  ImageMetadataResponse = object # ref object
    schemaVersion*: int
    mediaType*: string
    config*: ConfigItem
    layers*: seq[LayerItem]

type DockerHubClient* = ref object
  authData: Option[DockerAuthResponse]

proc newDockerHubHttpClient*(): DockerHubClient =
  return DockerHubClient(
    authData: none(DockerAuthResponse),
  )

proc fetchDockerHubToken*(client: DockerHubClient, image: string): void =
  let httpClient = newHttpClient()
  defer: httpClient.close()

  let response = httpClient.get(AuthUrl % [image])
  if not response.code.is2xx:
    raise newException(OSError, fmt"Cannot authenticate: {response.code}")

  client.authData = some parseJson(response.body).to(DockerAuthResponse)

proc fetchImageManifestMetadata(
  client: DockerHubClient,
  image: string,
  tag: string,
): ManifestMetadataResponse =
  if client.authData.isNone:
    raise newException(OSError, "Missing token, you need to fetch it first")

  let httpClient = newHttpClient()
  defer: httpClient.close()

  httpClient.headers = newHttpHeaders({
    "Authorization": "Bearer " & client.authData.get.token,
    "Accept": "application/vnd.docker.distribution.manifest.list.v2+json",
  })

  let response = httpClient.get(ManifestUrl % [image, tag])
  if not response.code.is2xx:
    raise newException(OSError, fmt"Failed to fetch manifest for image: {response.code}")

  # FIX: Not available in Nim 1.0.6
  #return parseJson(response.body).jsonTo(
  #  MetadataResponse[ManifestMetadata],
  #  opt = Joptions(allowExtraKeys: true, allowMissingKeys: true),
  #)
  return parseJson(response.body).to(ManifestMetadataResponse)

proc fetchImageLayersMetadata(
  client: DockerHubClient,
  image: string,
  digest: string,
): ImageMetadataResponse =
  let httpClient = newHttpClient()
  defer: httpClient.close()

  httpClient.headers = newHttpHeaders({
    "Authorization": "Bearer " & client.authData.get.token,
    "Accept": [
      "application/vnd.docker.distribution.manifest.v2+json",
      "application/vnd.docker.distribution.manifest.list.v2+json",
      "application/vnd.oci.image.manifest.v1+json",
      "application/vnd.oci.image.index.v1+json",
    ].join(",")
  })

  let response = httpClient.get(ManifestUrl % [image, digest])
  if not response.code.is2xx:
    raise newException(
      OSError,
      fmt"Failed to fetch manifest for image ({response.code}): {response.body}"
    )

  # FIX: Not available in Nim 1.0.6
  #return parseJson(response.body).jsonTo(
  #  MetadataResponse[ImageMetadata],
  #  opt = Joptions(allowExtraKeys: true, allowMissingKeys: true),
  #)
  return parseJson(response.body).to(ImageMetadataResponse)

proc fetchLayerData(
  client: DockerHubClient,
  image: string,
  digest: string,
  streamHandler: proc (bodyStream: Stream): void,
): void =
  let httpClient = newHttpClient()
  defer: httpClient.close()

  httpClient.headers = newHttpHeaders({
    "Authorization": "Bearer " & client.authData.get.token,
    "Accept": "application/vnd.oci.image.layer.v1.tar+gzip",
  })

  let response = httpClient.get(LayerUrl % [image, digest])
  if not response.code.is2xx:
    raise newException(
      OSError,
      fmt"Failed to fetch the layer ({response.code}): {response.body}"
    )

  streamHandler(response.bodyStream)

# FIX: For now only 1-layered images are supported
proc fetchImage*(imageName, imageTag: string): void =
  let dockerClient = new DockerHubClient
  dockerClient.fetchDockerHubToken(imageName)

  let imageMetadata = dockerClient.fetchImageManifestMetadata(imageName, imageTag)
  let matchingImageManifests = imageMetadata.manifests.filterIt(
    it.platform.os == "linux" and
    it.platform.architecture == getArchitecture()
  )
  if matchingImageManifests.len == 0:
    raise newException(IOError, "Unknown CPU architecture")

  let imageManifest = matchingImageManifests[0]
  let imageLayersManifest = dockerClient.fetchImageLayersMetadata(
    imageName,
    imageManifest.digest
  )
  if imageLayersManifest.layers.len == 0:
    raise newException(IOError, "Image has no layers")

  let layerManifest = imageLayersManifest.layers[0]

  let fullImageName = imageName & ":" & imageTag
  let imageFilePath = ImagesPath/(fullImageName & ".tar.gz")

  # FIX: Needs newer version of Nim
  # dockerClient.fetchLayerData(imageName, layerManifest.digest, (stream: Stream) => (
  dockerClient.fetchLayerData(imageName, layerManifest.digest, proc (stream: Stream): void =
    var buffer {.noinit.}: array[1024*1024, byte]

    let destinationFile = openFileStream(imageFilePath, fmWrite, buffer.len)
    defer:
      destinationFile.flush()
      destinationFile.close()

    var totalBytesDownloaded = 0
    while not stream.atEnd:
      let bytesRead = stream.readData(addr buffer, buffer.len)
      destinationFile.writeData(addr buffer, bytesRead)

      totalBytesDownloaded += bytesRead

      #echo (
      #  "Downloading... " &
      #  $(totalBytesDownloaded / layerManifest.size * 100) & "%"
      #)
  )
  # ))

  let shaCommandResult = execProcess(
    command = "sha256sum",
    args = [imageFilePath],
    options = {poUsePath, poStdErrToStdOut},
  )
  let shaSumAsDigest = "sha256:" & shaCommandResult.split(" ")[0]
  if shaSumAsDigest != layerManifest.digest:
    raise newException(
      OSError,
      fmt"Hash mismatch! Expected {layerManifest.digest}, actual: {shaSumAsDigest}"
    )


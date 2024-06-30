#!/bin/sh

CHROOT_LOCAL_BIN_DIR="./runtime-data/containers/codecrafters-docker-explorer/usr/local/bin"
FULL_FILE_PATH="${CHROOT_LOCAL_BIN_DIR}/docker-explorer"

if [ ! -f "${FULL_FILE_PATH}" ]; then
	mkdir -p "${CHROOT_LOCAL_BIN_DIR}"
	(cd ./docker-explorer && go build -o dist/main.out ./main.go)
	mv ./docker-explorer/dist/main.out "${FULL_FILE_PATH}"
fi

unshare --user --map-root-user nimble test "$@"

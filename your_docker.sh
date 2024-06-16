#!/bin/sh
set -e
tmpFile=$(mktemp)
nim compile --verbosity:0 --hints:off --out:"$tmpFile" src/main.nim
exec "$tmpFile" "$@"

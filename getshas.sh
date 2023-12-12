#!/usr/bin/env bash

set -euo pipefail

getsha() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1"
  else
    shasum -a 256 "$1"
  fi
}

readonly version="$1"
echo "readonly version=$version"

for os in darwin linux
do
  for arch in amd64 arm64
  do
    filename=buildifier-$os-$arch
    url=https://github.com/bazelbuild/buildtools/releases/download/$version/$filename
    bin=$(mktemp)
    if ! curl --fail --silent -L "$url" -o "$bin"; then
      echo "error: failed to download $url, is the version correct?"
      exit 1
    fi

    sha=$(getsha "$bin" | cut -d ' ' -f 1)
    echo "# shellcheck disable=SC2034"
    echo "readonly ${os}_${arch}_sha=$sha"
  done
done

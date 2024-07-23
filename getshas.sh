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

# List of operating systems and architectures
for os in darwin linux windows
do
  for arch in amd64 arm64
  do
    # Skip arm64 for windows since there is no build for it
    if [[ $os == windows && $arch == arm64 ]]; then
      continue
    fi

    # Special handling for Windows to include ".exe" extension
    if [[ $os == windows ]]; then
      filename="buildifier-$os-$arch.exe"
    else
      filename="buildifier-$os-$arch"
    fi

    url="https://github.com/bazelbuild/buildtools/releases/download/$version/$filename"
    bin=$(mktemp)
    if ! curl --fail --silent -L "$url" -o "$bin"; then
      echo "error: failed to download $url, is the version correct?"
      exit 1
    fi

    sha=$(getsha "$bin" | cut -d ' ' -f 1)
    echo "# shellcheck disable=SC2034"
    echo "readonly ${os}_${arch}_sha=$sha"

    rm -f "$bin"
  done
done

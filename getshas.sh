#!/usr/bin/env bash

set -euo pipefail

readonly version="$1"
echo "readonly version=$version"

for os in darwin linux
do
  for arch in amd64 arm64
  do
    filename=buildifier-$os-$arch
    url=https://github.com/bazelbuild/buildtools/releases/download/$version/$filename
    bin=$(mktemp)
    curl --fail --silent -L "$url" -o "$bin"
    if [[ "$os" == darwin ]] && ! type sha256sum > /dev/null; then
       alias sha256sum="shasum -a 256"
    fi
    sha=$(sha256sum "$bin" | cut -d ' ' -f 1)
    echo "# shellcheck disable=SC2034"
    echo "readonly ${os}_${arch}_sha=$sha"
  done
done

#!/bin/bash

set -euo pipefail

readonly version=6.0.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=3f8ab7dd5d5946ce44695f29c3b895ad11a9a6776c247ad5273e9c8480216ae1
# shellcheck disable=SC2034
readonly darwin_arm64_sha=21fa0d48ef0b7251eb6e3521cbe25d1e52404763cd2a43aa29f69b5380559dd1
# shellcheck disable=SC2034
readonly linux_amd64_sha=7ff82176879c0c13bc682b6b0e482d670fbe13bbb20e07915edb0ad11be50502
# shellcheck disable=SC2034
readonly linux_arm64_sha=9ffa62ea1f55f420c36eeef1427f71a34a5d24332cb861753b2b59c66d6343e2

os=linux
if [[ $OSTYPE == darwin* ]]; then
  os=darwin
fi

arch=amd64
if [[ $(uname -m) == arm64 ]]; then
  arch=arm64
fi

readonly filename=buildifier-$os-$arch
readonly url=https://github.com/bazelbuild/buildtools/releases/download/$version/$filename
readonly binary_dir=~/.cache/pre-commit/buildifier/$os-$arch-$version/buildifier
readonly binary=$binary_dir/buildifier-$1
shift

if [[ -x "$binary" ]]; then
  exec "$binary" "$@"
fi

readonly sha_accessor=${os}_${arch}_sha
readonly sha="${!sha_accessor}"
mkdir -p "$binary_dir"
tmp_binary=$(mktemp)

if ! curl --fail --location --retry 5 --retry-connrefused --silent --output "$tmp_binary" "$url"; then
  echo "error: failed to download buildifier" >&2
  exit 1
fi

if echo "$sha  $tmp_binary" | shasum --check --status; then
  chmod +x "$tmp_binary"

  # Protect against races of concurrent hooks downloading the same binary
  if [[ ! -x "$binary" ]]; then
    mv "$tmp_binary" "$binary"
  fi

  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi

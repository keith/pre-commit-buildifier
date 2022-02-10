#!/bin/bash

set -euo pipefail

readonly version=5.0.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=43e0f23b4cd9a4a150072ddf280bfd0e5cca74e3318103cbe1056e0bf22d0eed
# shellcheck disable=SC2034
readonly darwin_arm64_sha=8946ec86155f7357e1ecbe09d786fad8d04575f320a8521644b37e9abfb05645
# shellcheck disable=SC2034
readonly linux_amd64_sha=18a518a4b9b83bb96a115a681099ae6c115217e925a2dacfb263089e3a791b5d
# shellcheck disable=SC2034
readonly linux_arm64_sha=ab713d8b69bd394ea8c87acfa3be6b9d042c7764a10f5514ae456bdd12cd665c

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
readonly binary=$binary_dir/buildifier

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
  # Protect against races of concurrent hooks downloading the same binary
  if [[ ! -x "$binary" ]]; then
    mv "$tmp_binary" "$binary"
    chmod +x "$binary"
  fi

  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi

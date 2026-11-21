#!/usr/bin/env bash

set -euo pipefail

readonly version=v10.2.0
# shellcheck disable=SC2034
readonly darwin_amd64_sha=9e78881e91266e3567ed6d590f6c19bb5cd8cfa7aa80c7e1b6e479264d1051b8
# shellcheck disable=SC2034
readonly darwin_arm64_sha=d9c9c3a2826d1d8f592a9d463e62aed7f4dcacc5ab48e8de6be53c420b34b971
# shellcheck disable=SC2034
readonly linux_amd64_sha=470844069d710d0b7740e55007071c63e4d00be89a833dce5d1a91790e84dc28
# shellcheck disable=SC2034
readonly linux_arm64_sha=e33b41bdb36eca5dfa69647333f4f148272654b98cddcea12f38fac5ec0a00ff
# shellcheck disable=SC2034
readonly windows_amd64_sha=ae9b0632ff4bc56607b9c8512716b7fd63371387136005d25e94ec668f89361d
# shellcheck disable=SC2034
readonly windows_arm64_sha=bf213d214296346f859a6f1135168161cf86d7c1ca49df41426790a139b574e8

os=linux
extension=""
if [[ $OSTYPE == darwin* ]]; then
  os=darwin
elif [[ $OSTYPE == msys* || $OSTYPE == cygwin* || $OSTYPE == win32 ]]; then
  os=windows
  extension=".exe"
fi

arch=amd64
if [[ $(uname -m) == arm64 ]] || [[ $(uname -m) == aarch64 ]]; then
  arch=arm64
fi

readonly filename=buildifier-$os-${arch}${extension}
readonly default_base_url=https://github.com/bazelbuild/buildtools/releases/download/$version
readonly binary_dir="${XDG_CACHE_HOME:-$HOME/.cache}"/pre-commit/buildifier/$os-$arch-$version/buildifier
readonly binary=$binary_dir/buildifier-$1
shift

# Parse --buildifier-base-url argument if present.
base_url_arg=""
buildifier_args=()
for arg in "$@"; do
  if [[ $arg == --buildifier-base-url=* ]]; then
    base_url_arg="${arg#--buildifier-base-url=}"
  else
    buildifier_args+=("$arg")
  fi
done
# Replace positional args with filtered args (handles empty array safely with set -u).
set -- ${buildifier_args[@]+"${buildifier_args[@]}"}

readonly base_url=${base_url_arg:-${BUILDIFIER_BASE_URL:-$default_base_url}}
readonly url=$base_url/$filename

# Unset DISPLAY to prevent deprecation warning about selecting
# diff program via environment variables. WSL always sets DISPLAY.
unset DISPLAY

if [[ -x "$binary" ]]; then
  exec "$binary" "$@"
fi

readonly sha_accessor=${os}_${arch}_sha
readonly sha="${!sha_accessor}"

mkdir -p "$binary_dir"
# Create tmp_binary in the same directory as binary to make mv atomic.
tmp_binary="$(mktemp --tmpdir="$binary_dir")"
trap 'rm -f "$tmp_binary"' EXIT

download() {
  if which wget &> /dev/null; then
    wget --retry-connrefused --quiet --output-document "$2" "$1"
  else
    curl --fail --location --retry 5 --retry-connrefused --silent --output "$2" "$1"
  fi
}

if ! download "$url" "$tmp_binary"; then
  echo "error: failed to download buildifier" >&2
  exit 1
fi

shabin=shasum
if ! command -v "$shabin" >/dev/null; then
  shabin=sha256sum
fi

if echo "$sha  $tmp_binary" | $shabin --check --status; then
  chmod +x "$tmp_binary"
  mv "$tmp_binary" "$binary"
  exec "$binary" "$@"
else
  echo "error: buildifier sha mismatch" >&2
  rm -f "$binary"
  exit 1
fi

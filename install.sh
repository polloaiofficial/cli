#!/bin/sh
# pollo-cli installer.
#
#   curl -fsSL https://raw.githubusercontent.com/polloaiofficial/cli/main/install.sh | sh
#
# Installs the `pollo` binary for macOS or Linux. On Windows, install from npm
# instead (`npm i -g @pollo-ai/cli`).
#
# The binary comes from the npm registry — the same per-platform packages that
# `npm i -g @pollo-ai/cli` installs. That makes the registry the single source of
# truth for releases: there is no second place to publish to and no version
# pointer to keep in sync, because the version installed here is whatever npm's
# `latest` dist-tag resolves to.
#
# Integrity is checked against the registry's own `dist.integrity` (sha512) —
# the same value npm verifies during a normal install.
#
# Overrides (env vars):
#   POLLO_CLI_VERSION   pin a version instead of npm's `latest`
#   POLLO_INSTALL_DIR   install directory (default: /usr/local/bin if writable,
#                       else ~/.local/bin)
#   POLLO_REGISTRY      registry base URL, for anyone installing through a
#                       private or proxying registry instead of npmjs.org. Note
#                       that public mirrors often lag behind a fresh release, so
#                       a newly published version may 404 there for a while.
set -eu

SCOPE="@pollo-ai"
REGISTRY="${POLLO_REGISTRY:-https://registry.npmjs.org}"
REGISTRY="${REGISTRY%/}"

err() { echo "error: $*" >&2; exit 1; }

# fetch <url> -> stdout
fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$1"
  else err "need curl or wget"; fi
}
# download <url> <dest>
download() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  else wget -qO "$2" "$1"; fi
}
# json_field <name> — pull one string field out of a JSON blob on stdin.
# Deliberately dumb: the two fields we read ("version", "integrity") each appear
# once in the documents requested below, so a regex beats requiring jq/python.
json_field() {
  sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -n 1
}

# --- detect platform (npm's os/cpu naming, not Go's GOOS/GOARCH) ---
os=$(uname -s)
arch=$(uname -m)
case "$os" in
  Darwin) os=darwin ;;
  Linux)  os=linux ;;
  *) err "unsupported OS: $os. On Windows, install from npm: npm i -g $SCOPE/cli" ;;
esac
case "$arch" in
  x86_64|amd64) cpu=x64 ;;
  arm64|aarch64) cpu=arm64 ;;
  *) err "unsupported arch: $arch" ;;
esac

pkg="cli-$os-$cpu"

# --- resolve version ---
if [ -n "${POLLO_CLI_VERSION:-}" ]; then
  version="$POLLO_CLI_VERSION"
else
  version=$(fetch "$REGISTRY/$SCOPE/cli/latest" | json_field version) \
    || err "cannot reach $REGISTRY"
fi
[ -n "$version" ] || err "could not determine which version to install"

echo "Installing pollo $version ($os/$cpu)"

# --- resolve the tarball and its integrity from the registry ---
meta=$(fetch "$REGISTRY/$SCOPE/$pkg/$version") \
  || err "$SCOPE/$pkg@$version not found on $REGISTRY"
integrity=$(printf '%s' "$meta" | json_field integrity)
# Tarball paths under /-/ use the package name without its scope.
url="$REGISTRY/$SCOPE/$pkg/-/$pkg-$version.tgz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

download "$url" "$tmp/pkg.tgz" || err "download failed: $url"

# --- verify against the registry's sha512 (best effort: skip if no tool) ---
case "${integrity:-}" in
  sha512-*)
    want=${integrity#sha512-}
    if command -v openssl >/dev/null 2>&1; then
      got=$(openssl dgst -sha512 -binary "$tmp/pkg.tgz" | openssl base64 -A)
    else
      got=""
    fi
    [ -z "$got" ] || [ "$got" = "$want" ] || err "checksum mismatch for $pkg@$version"
    ;;
esac

tar -xzf "$tmp/pkg.tgz" -C "$tmp" || err "could not unpack $pkg@$version"
[ -f "$tmp/package/bin/pollo" ] || err "$pkg@$version does not contain bin/pollo"
chmod +x "$tmp/package/bin/pollo"

# --- choose install dir ---
if [ -n "${POLLO_INSTALL_DIR:-}" ]; then
  dir="$POLLO_INSTALL_DIR"
elif [ -w /usr/local/bin ] 2>/dev/null; then
  dir=/usr/local/bin
else
  dir="$HOME/.local/bin"
fi
mkdir -p "$dir"
mv "$tmp/package/bin/pollo" "$dir/pollo"

echo "Installed: $dir/pollo"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "note: $dir is not on your PATH; add it, e.g.  export PATH=\"$dir:\$PATH\"" ;;
esac
"$dir/pollo" version 2>/dev/null || true

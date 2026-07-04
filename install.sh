#!/bin/sh
# Installs the vega CLI from GitHub Releases.
#
#   curl -fsSL https://raw.githubusercontent.com/NebuSec/vega-skill/main/install.sh | sh
#
# Environment:
#   VEGA_VERSION      release tag to install (default: latest)
#   VEGA_INSTALL_DIR  target directory (default: ~/.local/bin)
set -eu

REPO="NebuSec/vega-skill"
INSTALL_DIR="${VEGA_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${VEGA_VERSION:-latest}"

os=$(uname -s)
arch=$(uname -m)
case "$os" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "error: unsupported OS: $os (see https://github.com/$REPO/releases)" >&2; exit 1 ;;
esac
case "$arch" in
  x86_64 | amd64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) echo "error: unsupported architecture: $arch" >&2; exit 1 ;;
esac

asset="vega-$os-$arch.tar.gz"
if [ "$VERSION" = "latest" ]; then
  url="https://github.com/$REPO/releases/latest/download/$asset"
else
  url="https://github.com/$REPO/releases/download/$VERSION/$asset"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "downloading $url" >&2
curl -fsSL "$url" -o "$tmp/$asset"
tar -xzf "$tmp/$asset" -C "$tmp"

mkdir -p "$INSTALL_DIR"
install -m 755 "$tmp/vega" "$INSTALL_DIR/vega"
echo "installed $("$INSTALL_DIR/vega" --version) to $INSTALL_DIR/vega" >&2

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "warning: $INSTALL_DIR is not on PATH — add it to your shell profile" >&2 ;;
esac

#!/bin/sh
# Download the latest mithrl CLI binary for this machine.
#
#   sh install-mithrl.sh                                  # into the current directory
#   MITHRL_INSTALL_DIR=~/.local/bin sh install-mithrl.sh  # somewhere on your PATH
#
# Already have mithrl? `mithrl update` is the supported upgrade path, and it
# verifies the release signature, which this script cannot.
set -eu

REPO=mithrl-labs/public-releases
TAG_PREFIX=lattice-cli/
INSTALL_DIR=${MITHRL_INSTALL_DIR:-.}

die() { printf 'install-mithrl: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required but was not found."

# Platform key, matching manifest.json's own keys. Only these three are built,
# so anything else fails here rather than fetching a binary that can't run.
os=$(uname -s)
arch=$(uname -m)
case "$os:$arch" in
    Darwin:arm64 | Darwin:aarch64) key=darwin-arm64  ; exe= ;;
    Linux:x86_64 | Linux:amd64)    key=linux-x86_64  ; exe= ;;
    MINGW*:* | MSYS*:* | CYGWIN*:*) key=windows-amd64 ; exe=.exe ;;
    Darwin:*) die "no macOS build for $arch yet -- Apple Silicon only." ;;
    Linux:*)  die "no Linux build for $arch yet -- x86_64 only." ;;
    *)        die "unsupported platform: $os $arch." ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

# This repo hosts several products and GitHub's "Latest" marker is repo-wide,
# so take the newest release tagged lattice-cli/* rather than /releases/latest.
curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=100" -o "$work/releases.json" ||
    die "could not reach the GitHub API. It allows 60 requests/hour per IP unauthenticated -- if you share an egress IP, wait and retry."
tag=$(grep -m1 "\"tag_name\": \"$TAG_PREFIX" "$work/releases.json" | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
[ -n "$tag" ] || die "no ${TAG_PREFIX}* release found in this repo."

# GitHub reads a literal / in a tag as a path separator, so it has to be encoded.
base="https://github.com/$REPO/releases/download/$(printf '%s' "$tag" | sed 's|/|%2F|g')"
asset="mithrl-$key$exe"

curl -fsSL "$base/manifest.json" -o "$work/manifest.json" || die "could not download manifest.json for $tag."
want=$(grep -A2 "\"$key\": {" "$work/manifest.json" | sed -nE 's/.*"sha256": "([a-f0-9]{64})".*/\1/p')
[ -n "$want" ] || die "manifest.json for $tag has no $key entry."

printf 'Downloading %s (%s)...\n' "$asset" "$tag"
curl -fL --progress-bar "$base/$asset" -o "$work/$asset" || die "could not download $asset for $tag."

if command -v shasum >/dev/null 2>&1; then
    got=$(shasum -a 256 "$work/$asset" | cut -d' ' -f1)
elif command -v sha256sum >/dev/null 2>&1; then
    got=$(sha256sum "$work/$asset" | cut -d' ' -f1)
else
    die "need shasum or sha256sum to check the download."
fi
[ "$got" = "$want" ] || die "checksum mismatch for $asset -- got $got, manifest says $want. Not installing."

mkdir -p "$INSTALL_DIR" || die "could not create $INSTALL_DIR."
# Owner-only: a downloaded binary shouldn't hand access to every other account.
chmod u+rwx "$work/$asset"
mv "$work/$asset" "$INSTALL_DIR/mithrl$exe" || die "could not write to $INSTALL_DIR -- set MITHRL_INSTALL_DIR to somewhere you can write."

target=$(cd "$INSTALL_DIR" && pwd)/mithrl$exe
printf 'Installed %s (checksum matches the release manifest).\n' "$target"
case ":${PATH}:" in
    *":$(dirname "$target"):"*) printf 'Run: mithrl --version\n' ;;
    *) printf 'Not on your PATH yet. Run: %s --version\n' "$target" ;;
esac

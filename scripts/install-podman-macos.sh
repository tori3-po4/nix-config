#!/bin/bash
set -euo pipefail

# Called by darwin/podman.nix with a version and a hash-verified pkg in the store.
# Keep macOS tools (including those used by the pkg's scripts) on a known PATH.
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 VERSION HASH_VERIFIED_PKG" >&2
  exit 2
fi

version=$1
package=$2
podman=/opt/podman/bin/podman

if [[ $(uname -s) != Darwin || $(uname -m) != arm64 ]]; then
  echo "This Podman installer requires an Apple Silicon Mac." >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "Run through sudo darwin-rebuild switch; installing the pkg requires root." >&2
  exit 1
fi

# Refuse a remaining Homebrew installation instead of overwriting its files.
# nix-darwin normally removes undeclared formulae before calling this script.
for prefix in /opt/homebrew /usr/local; do
  if [[ -e $prefix/opt/podman || -L $prefix/opt/podman ]]; then
    echo "Homebrew Podman remains at $prefix/opt/podman; uninstall it before retrying." >&2
    exit 1
  fi
done

receipt_version() {
  pkgutil --pkg-info com.redhat.podman 2>/dev/null |
    awk '$1 == "version:" { print $2 }'
}

is_installed() {
  [[ $(receipt_version) == "$version" ]] &&
    [[ -x $podman ]] &&
    [[ $("$podman" --version) == "podman version $version" ]]
}

if is_installed; then
  echo "Podman $version is already installed."
  exit 0
fi

if [[ ! -f $package ]]; then
  echo "Podman installer not found: $package" >&2
  exit 1
fi

# Fail before installation if macOS cannot validate the signature/notarization.
pkgutil --check-signature "$package"
spctl --assess --type install --verbose=2 "$package"
installer -pkg "$package" -target /

if ! is_installed; then
  echo "Podman installation did not produce the expected version $version." >&2
  exit 1
fi

echo "Podman $version installed. Create/start its machine as your normal user."

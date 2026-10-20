#!/usr/bin/env bash
set -euo pipefail

# Install software that is intentionally not managed by Home Manager on
# non-NixOS Linux.  Run this setup script before applying Home Manager, which
# manages dotfiles, shell configuration, Emacs and user Flatpak apps.  This script
# is idempotent and targets Fedora/dnf first, with a best-effort Debian/Ubuntu apt
# path.

DRY_RUN=0
WITH_NPM_TOOLS=1
WITH_VIRTUALBOX=1

usage() {
  cat <<'USAGE'
Usage: scripts/install-linux-software.sh [--dry-run] [--no-npm-tools] [--no-virtualbox]

Installs host software with the native package manager instead of Home Manager.
Supported package managers: dnf, apt-get.
VirtualBox is included on x86_64: RPM Fusion on Fedora, distro packages on apt.
Missing apt repositories are configured automatically on Ubuntu and Debian 12/13.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --no-npm-tools) WITH_NPM_TOOLS=0 ;;
    --no-virtualbox) WITH_VIRTUALBOX=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

prepare_virtualbox_apt_repository() {
  local candidate
  candidate=$(LC_ALL=C apt-cache policy virtualbox | awk '/Candidate:/ {print $2}')
  if [ -n "$candidate" ] && [ "$candidate" != '(none)' ]; then
    return 0
  fi

  local ID='' VERSION_CODENAME=''
  # shellcheck source=/dev/null
  . /etc/os-release
  case "$ID" in
    ubuntu)
      run sudo apt-get install -y software-properties-common
      run sudo add-apt-repository --yes --no-update universe
      run sudo add-apt-repository --yes --no-update multiverse
      ;;
    debian)
      local keyring
      case "$VERSION_CODENAME" in
        bookworm) keyring=/etc/apt/trusted.gpg.d/fasttrack-archive-keyring.gpg ;;
        trixie) keyring=/usr/share/keyrings/fasttrack-archive-keyring.gpg ;;
        *) echo "VirtualBox repository setup supports Debian 12/13; configure a repository or use --no-virtualbox." >&2; return 1 ;;
      esac
      run sudo apt-get install -y ca-certificates fasttrack-archive-keyring
      # Keep our entries in one file; pass its contents as data, including in dry runs.
      run sudo sh -c 'printf "%s\n" "$1" > "$2"' sh "Types: deb
URIs: https://deb.debian.org/debian
Suites: ${VERSION_CODENAME}-backports
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://fasttrack.debian.net/debian-fasttrack
Suites: ${VERSION_CODENAME}-fasttrack ${VERSION_CODENAME}-backports-staging
Components: main contrib
Signed-By: ${keyring}" /etc/apt/sources.list.d/nix-config-virtualbox.sources
      ;;
    *) echo "No VirtualBox apt candidate for ${ID}; configure a repository or use --no-virtualbox." >&2; return 1 ;;
  esac
  run sudo apt-get update
}

install_virtualbox() {
  [ "$WITH_VIRTUALBOX" -eq 1 ] || return 0
  if [ "$(uname -m)" != x86_64 ]; then
    echo "Skipping VirtualBox: this installer supports x86_64 hosts only." >&2
    return 0
  fi

  local kernel
  kernel=$(uname -r)
  case "$1" in
    dnf)
      local fedora
      fedora=$(rpm -E '%{?fedora}')
      case "$fedora" in
        ''|*[!0-9]*) echo "Skipping VirtualBox: the dnf path requires Fedora." >&2; return 0 ;;
      esac
      if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        run sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora}.noarch.rpm"
      fi
      run sudo dnf install -y VirtualBox akmod-VirtualBox "kernel-devel-${kernel}"
      run sudo akmods --force --kernels "$kernel" --akmod VirtualBox
      run sudo systemctl enable --now vboxdrv.service
      ;;
    apt-get)
      prepare_virtualbox_apt_repository
      run sudo apt-get install -y build-essential "linux-headers-${kernel}" virtualbox virtualbox-dkms virtualbox-qt
      run sudo modprobe vboxdrv
      ;;
  esac
  run sudo usermod -aG vboxusers "${SUDO_USER:-$(id -un)}"
  echo "VirtualBox: log out and back in to activate vboxusers membership."
}

install_dnf() {
  install_virtualbox dnf

  local packages=(
    # basic CLI / shell
    ripgrep fd-find fzf jq bat eza coreutils ncurses git git-filter-repo gh
    neovim tmux direnv pandoc
    # languages / build tools
    nodejs npm pnpm uv sbcl automake cmake meson ninja-build pkgconf-pkg-config
    make gcc gcc-c++ lld lldb llvm clang-tools-extra rustfmt cargo
    # media / documents / network / crypto
    ffmpeg ImageMagick libwebp-tools poppler-utils yt-dlp gnupg2 age
    # misc / TeX / lint-format
    sqlite aspell aspell-en texlive-scheme-full ghostscript shellcheck shfmt
    python3-ruff
    # GUI / integration that belongs to the OS package manager
    flatpak xdg-desktop-portal xdg-desktop-portal-gtk
  )

  run sudo dnf install -y "${packages[@]}"

  # Install optional GUI packages only when the enabled repositories provide
  # them.  Fedora provides alacritty in the main repositories; RHEL-compatible
  # distributions may need EPEL or may not provide it.
  local optional_packages=(alacritty code)
  local available_optional=()
  local package
  for package in "${optional_packages[@]}"; do
    if [ "$DRY_RUN" -eq 1 ] || rpm -q "$package" >/dev/null 2>&1 || dnf -q list --available "$package" >/dev/null 2>&1; then
      available_optional+=("$package")
    else
      echo "Skipping optional package not available in enabled dnf repositories: $package" >&2
    fi
  done
  if [ "${#available_optional[@]}" -gt 0 ]; then
    run sudo dnf install -y "${available_optional[@]}"
  fi

  cat <<'NOTE'

[dnf note]
Some tools from the old Nix profile are not consistently available in Fedora
repositories, or require external repositories:
  codex, pixi, elan, flyctl, nil/nixd, lua-language-server, tex-fmt,
  tree-sitter-cli, marksman, dockerfile/yaml/bash/vscode language servers.
Install those per-project, via their upstream installers, or add a dedicated
script section once you decide the preferred source.

If `code` was skipped, enable Microsoft's VS Code repository first:
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
NOTE
}

install_apt() {
  local packages=(
    ripgrep fd-find fzf jq bat eza coreutils ncurses-bin git git-filter-repo gh
    neovim alacritty tmux direnv pandoc nodejs npm pnpm sbcl automake cmake meson
    ninja-build pkgconf make gcc g++ lld lldb llvm clang-tools rustfmt cargo
    ffmpeg imagemagick webp poppler-utils yt-dlp gnupg age sqlite3 aspell aspell-en
    texlive-full ghostscript shellcheck shfmt ruff flatpak xdg-desktop-portal
    xdg-desktop-portal-gtk
  )

  run sudo apt-get update
  install_virtualbox apt-get
  run sudo apt-get install -y "${packages[@]}"

  cat <<'NOTE'

[apt note]
VS Code, GitHub CLI, uv, pixi, elan, flyctl, many LSP servers and codex may
need vendor repositories or upstream installers depending on your distribution.
This apt path is best-effort; Fedora/dnf is the primary target for this repo.
NOTE
}

install_npm_tools() {
  have npm || { echo "npm command not found; skipping npm-based tools" >&2; return 0; }

  # Keep global npm tools in the user's home instead of /usr.
  local prefix="${HOME}/.local/share/npm-global"
  run mkdir -p "$prefix"
  run npm config set prefix "$prefix"

  local npm_tools=(
    typescript
    prettier
    pyright
    typescript-language-server
    @astrojs/language-server
    @tailwindcss/language-server
    vscode-langservers-extracted
    bash-language-server
    yaml-language-server
    dockerfile-language-server-nodejs
  )
  run npm install -g "${npm_tools[@]}"

  # Pi's official npm install skips lifecycle scripts and needs Node.js >=22.19.
  # Reject unsupported engines instead of installing a CLI that cannot run.
  run npm install -g --ignore-scripts --engine-strict @earendil-works/pi-coding-agent

  cat <<NOTE

[npm note]
Home Manager adds ${prefix}/bin to PATH on Linux.
To use these tools in the current shell before applying Home Manager:
  export PATH="${prefix}/bin:\$PATH"
NOTE
}

if have dnf; then
  install_dnf
elif have apt-get; then
  install_apt
else
  echo "No supported package manager found. Expected dnf or apt-get." >&2
  exit 1
fi

if [ "$WITH_NPM_TOOLS" -eq 1 ]; then
  install_npm_tools
fi

cat <<'DONE'

Done. Apply Home Manager, then re-open your shell:
  home-manager switch --flake ~/nix-config#default --impure

For first setup, when home-manager is not installed yet:
  nix run home-manager/master -- switch --flake ~/nix-config#default --impure -b hmbak

Home Manager manages dotfiles, shell/session settings, Emacs and user Flatpak apps.
DONE

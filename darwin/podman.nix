{ lib, pkgs, ... }:
let
  # https://podman.io/docs/installation recommends the official macOS installer.
  # Update the version and hash together using the release's shasums file.
  version = "6.1.4";
  installer = pkgs.fetchurl {
    url = "https://github.com/podman-container-tools/podman/releases/download/v${version}/podman-installer-macos-arm64.pkg";
    hash = "sha256-SPZ1Yi9mIzyiEW5n/atB7Z28wltIt4qObvC+ZUkDHSI=";
  };
in
{
  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
      message = "The pinned Podman macOS installer supports Apple Silicon only.";
    }
  ];

  # nix-darwin sets PATH itself; /etc/paths.d from the pkg is not sufficient.
  environment.systemPath = [ "/opt/podman/bin" ];

  system.build.podmanInstaller = installer;

  # Fetch/verify in the Nix build, install as root only during activation.
  # postActivation runs after Homebrew's cleanup, avoiding mixed installations.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /bin/bash ${../scripts/install-podman-macos.sh} ${lib.escapeShellArg version} ${installer}
  '';
}

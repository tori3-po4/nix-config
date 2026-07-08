{
  pkgs,
  inputs,
  ...
}:
{
  # Hermes Agent (Nous Research)。設定や skills は chezmoi 側で管理する。
  # Nix は Hermes 本体の導入だけを担当する。
  home.packages = [
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

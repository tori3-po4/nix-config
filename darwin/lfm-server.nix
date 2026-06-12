{ username, inputs, pkgs, ... }:
let
  # LFM2.5 (MLX) の OpenAI 互換サーバを launchd で常駐させる。
  #   upstream: github:tori3-po4/LFM2.5_for_MLX (flake input = inputs.lfm2-agent)
  # サーバ実体は uv.lock から uv2nix でビルドした Nix package を使う(=完全 Nix 管理)。
  # 開発用 ~/devs/my-LFM2.5-agent/.venv とは独立だが、同じ uv.lock 由来で版は一致する。
  # MLX は Metal/GPU を使うため LaunchDaemon(system) ではなく
  # LaunchAgent(user) で GUI ログインセッション内に常駐させる必要がある。
  home = "/Users/${username}";
  lfm = inputs.lfm2-agent.packages.${pkgs.system}.default;
in
{
  launchd.user.agents.lfm2-serve = {
    command = "${lfm}/bin/lfm2-serve --port 8080";

    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true; # 常駐(クラッシュ時も再起動)。常時 ~5GB RAM を占有する。
      StandardOutPath = "${home}/Library/Logs/lfm2-serve.log";
      StandardErrorPath = "${home}/Library/Logs/lfm2-serve.err.log";
      # 初回起動時に HuggingFace からモデルを ~/.cache/huggingface へ DL するため
      # HOME が要る(launchd の最小環境には無い)。
      EnvironmentVariables = {
        HOME = home;
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };
}

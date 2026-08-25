{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  # Zed の Edit Prediction 用ローカル FIM サーバー。
  # 初回起動時に llama.cpp の既定 Qwen 2.5 Coder 1.5B GGUF を取得する。
  launchd.user.agents.llama-cpp-fim = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.llama-cpp}/bin/llama-server"
        "--fim-qwen-1.5b-default"
        "--alias"
        "qwen2.5-coder-1.5b-base"
        "--host"
        "127.0.0.1"
        "--port"
        "18080"
        "--cors-origins"
        "localhost"
        "--ctx-size"
        "8192"
        "--parallel"
        "1"
        "--gpu-layers"
        "all"
        "--flash-attn"
        "on"
        "--cache-reuse"
        "256"
        "--sleep-idle-seconds"
        "300"
        "--no-webui"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
    };
  };
}

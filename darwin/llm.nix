{
  lib,
  username,
  pkgs,
  ...
}:
let
  home = "/Users/${username}";
  model = "LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M";
in
{
  # LFM2.5-8B-A1B Q4_K_M を llama.cpp の OpenAI 互換サーバで常駐させる。
  # -hf は Hugging Face から GGUF を取得し、以後はローカルキャッシュを使う。
  # KV cache を q8_0 にすると llama.cpp 側の attn rot (Hadamard rotation) が自動判定で有効になる。
  launchd.user.agents.llama-server-lfm25 = {
    command = lib.escapeShellArgs [
      "${pkgs.llama-cpp}/bin/llama-server"
      "--host"
      "127.0.0.1"
      "--port"
      "8080"
      "--n-gpu-layers"
      "all"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
      "-hf"
      model
    ];

    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${home}/Library/Logs/llama-server-lfm25.log";
      StandardErrorPath = "${home}/Library/Logs/llama-server-lfm25.err.log";
      EnvironmentVariables = {
        HOME = home;
        HF_HOME = "${home}/.cache/huggingface";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };
}

{
  lib,
  username,
  pkgs,
  ...
}:
let
  home = "/Users/${username}";
  defaultModel = "LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M";
  gemma4E4b = "lmstudio-community/gemma-4-E4B-it-GGUF:Q4_K_M";
  granite8b = "unsloth/granite-4.1-8b-GGUF:Q6_K";
  gemma4_12bQat = "lmstudio-community/gemma-4-12B-it-QAT-GGUF:Q4_0";
  vibeThinker3b = "prithivMLmods/VibeThinker-3B-GGUF:Q4_K_M";
  routerPreset = pkgs.writeText "llama-router-models.ini" ''
    version = 1

    [${defaultModel}]
    hf-repo = ${defaultModel}
    load-on-startup = false

    [${gemma4E4b}]
    hf-repo = ${gemma4E4b}
    load-on-startup = false

    [${granite8b}]
    hf-repo = ${granite8b}
    load-on-startup = false

    [${gemma4_12bQat}]
    hf-repo = ${gemma4_12bQat}
    load-on-startup = false

    [${vibeThinker3b}]
    hf-repo = ${vibeThinker3b}
    load-on-startup = false
  '';
in
{
  # llama.cpp の OpenAI 互換サーバを router mode で起動する。
  # リクエストされたモデルは自動ロードし、アイドル時は model / KV cache を unload する。
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
      "--models-preset"
      routerPreset
      "--models-max"
      "1"
      "--models-autoload"
      "--sleep-idle-seconds"
      "300"
    ];

    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${home}/Library/Logs/llama-server-lfm25.log";
      StandardErrorPath = "${home}/Library/Logs/llama-server-lfm25.err.log";
      EnvironmentVariables = {
        HOME = home;
        HF_HOME = "${home}/.cache/huggingface";
        LLAMA_CACHE = "${home}/.cache/llama.cpp";
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };
}

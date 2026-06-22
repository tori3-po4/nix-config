{ pkgs, inputs, ... }:
{
  # Hermes Agent (Nous Research)。nixpkgs 未収録なので公式 flake の
  # aarch64-darwin パッケージを直接参照する。terminal backend は docker(colima)、
  # モデルは ~/devs/my-LFM2.5-agent の OpenAI 互換サーバ(:8080)を使う。
  home.packages = [
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # ~/.hermes/config.yaml を home-manager で管理する。
  # 注意: nix store への read-only symlink になるため、`hermes config set` や
  # `hermes model` ウィザードからの書き込みは失敗する。モデル/エンドポイントの
  # 変更はこの Nix ファイルを編集して darwin-rebuild し直すこと。
  # API キー等の秘密情報は HM 管理外の ~/.hermes/.env に手で置く。
  home.file.".hermes/config.yaml".text = ''
    # このファイルは home-manager 管理 (home/hermes.nix)。直接編集しても rebuild で戻る。
    # モデル: ~/devs/my-LFM2.5-agent の OpenAI 互換サーバ (MLX / LFM2.5)
    # 端末: コマンド実行サンドボックスを colima(docker) 上に隔離する

    model:
      # llama.cpp router の既定モデル。モデル一覧は下の named provider に明示する。
      default: LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M
      provider: local-llama

    providers:
      local-llama:
        name: Local llama.cpp
        api: http://localhost:8080/v1
        transport: chat_completions
        default_model: LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M
        discover_models: false
        models:
          - LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M
          - lmstudio-community/gemma-4-E4B-it-GGUF:Q4_K_M
          - unsloth/granite-4.1-8b-GGUF:Q6_K
          - lmstudio-community/gemma-4-12B-it-QAT-GGUF:Q4_0
          - prithivMLmods/VibeThinker-3B-GGUF:Q4_K_M

    terminal:
      backend: docker
      # node + python が入った汎用サンドボックスイメージ (初回 colima 上に pull)
      docker_image: nikolaik/python-nodejs:python3.11-nodejs20

    display:
      skin: daylight  # Replace with "default", "ares", "mono", or your custom filename

  '';
}

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
      # serve.py の DEFAULT_MODEL と一致させること (配信モデル名 = この値)
      default: LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M
      provider: custom
      # base_url が設定されると Hermes は provider を無視してこの URL を直接叩く。
      # Hermes 本体はホストで動くので localhost で LFM サーバに届く
      # (docker サンドボックスは「コマンド実行」専用で、LLM 接続には使わない)。
      base_url: http://localhost:8080/v1
      # ローカルサーバは認証不要だが、空だと弾く実装があるためダミーを入れる
      api_key: local

    terminal:
      backend: docker
      # node + python が入った汎用サンドボックスイメージ (初回 colima 上に pull)
      docker_image: nikolaik/python-nodejs:python3.11-nodejs20
  '';
}

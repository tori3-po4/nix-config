{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  crawl4aiSkillDir = ./hermes-skills/research/crawl4ai-web-extract;

  defaultHermesConfig = pkgs.writeText "hermes-config.yaml" ''
    # このファイルは home-manager が初回だけ作成する通常ファイル。
    # `hermes config set` や `hermes model` から直接更新できる。
    # Nix 側の初期値を変える場合は home/hermes.nix を編集する。

    model:
      # llama.cpp router の既定モデル。モデル一覧は下の named provider に明示する。
      default: LiquidAI/LFM2.5-8B-A1B-GGUF:Q4_K_M
      provider: local-llama
      api_mode: chat_completions

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

    agent:
      max_turns: 150

    terminal:
      backend: docker
      # Docker Official Image の Ubuntu LTS。base image なので必要なツールは
      # sandbox 内で apt install する。
      docker_image: ubuntu:24.04

    web:
      backend: searxng
      use_gateway: false
      search_backend: searxng

    mcp_servers:
      crawl4ai:
        url: http://localhost:11235/mcp/sse
        transport: sse
        enabled: true
        headers:
          Authorization: "Bearer ''${CRAWL4AI_API_TOKEN}"

    browser:
      cloud_provider: local
      use_gateway: false

    display:
      skin: default  # Dark default skin; alternatives: "ares", "mono", or a custom filename
      interface: tui
      tool_progress: all
      language: ja
      tui_auto_resume_recent: false
      tui_agents_nudge: true
      tui_status_indicator: kaomoji

    onboarding:
      seen:
        busy_input_prompt: true

    _config_version: 31

    session_reset:
      mode: none

    image_gen:
      provider: openai-codex
      use_gateway: false
      model: gpt-image-2-medium

    platform_toolsets:
      cli:
        - browser
        - clarify
        - code_execution
        - computer_use
        - cronjob
        - delegation
        - file
        - image_gen
        - memory
        - session_search
        - skills
        - terminal
        - todo
        - tts
        - vision
        - web
      discord:
        - browser
        - clarify
        - code_execution
        - computer_use
        - cronjob
        - delegation
        - file
        - image_gen
        - memory
        - session_search
        - skills
        - terminal
        - todo
        - tts
        - vision
        - web

    known_plugin_toolsets:
      cli:
        - spotify
      discord:
        - spotify
  '';
in
{
  # Hermes Agent (Nous Research)。nixpkgs 未収録なので公式 flake の
  # aarch64-darwin パッケージを直接参照する。terminal backend は docker(colima)、
  # モデルは ~/devs/my-LFM2.5-agent の OpenAI 互換サーバ(:8080)を使う。
  home.packages = [
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # ~/.hermes/config.yaml は Hermes 自身が頻繁に更新するため、home.file では
  # 管理しない。初回だけ通常ファイルとして配置し、以降は外部からの変更を保つ。
  # 旧構成の nix store symlink が残っていれば、同じ内容の実ファイルへ移行する。
  # API キー等の秘密情報は ~/.hermes/.env に手で置く。
  home.activation.ensureHermesConfig = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    config_dir="${config.home.homeDirectory}/.hermes"
    config_file="$config_dir/config.yaml"

    if [ ! -e "$config_file" ] && [ ! -L "$config_file" ]; then
      $DRY_RUN_CMD mkdir -p "$config_dir"
      $DRY_RUN_CMD install -m 0644 ${defaultHermesConfig} "$config_file"
    elif [ -L "$config_file" ]; then
      target="$(readlink "$config_file" || true)"
      case "$target" in
        /nix/store/*)
          tmp_file="$config_file.hm-mutable"
          if [ -e "$config_file" ]; then
            $DRY_RUN_CMD cp "$config_file" "$tmp_file"
          else
            $DRY_RUN_CMD cp ${defaultHermesConfig} "$tmp_file"
          fi
          $DRY_RUN_CMD chmod u+w "$tmp_file"
          $DRY_RUN_CMD mv "$tmp_file" "$config_file"
          ;;
      esac
    elif [ ! -w "$config_file" ]; then
      $DRY_RUN_CMD chmod u+w "$config_file"
    fi
  '';

  home.activation.ensureHermesCrawl4AISkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    skill_dir="${config.home.homeDirectory}/.hermes/skills/research/crawl4ai-web-extract"
    $DRY_RUN_CMD mkdir -p "$skill_dir"
    $DRY_RUN_CMD install -m 0644 ${crawl4aiSkillDir}/SKILL.md "$skill_dir/SKILL.md"
  '';
}

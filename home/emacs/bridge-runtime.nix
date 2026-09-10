{ pkgs }:
let
  source = pkgs.fetchFromGitHub {
    owner = "manateelazycat";
    repo = "lsp-bridge";
    rev = "44593436dfdd9a31a2f1f60460c11f065ad01d2c";
    hash = "sha256-eLzp1rKJxdYFeGmez3gKmt9g0mQfxShY3E486nY4Wb0=";
  };
  python = pkgs.python313.withPackages (ps: with ps; [
    epc orjson packaging paramiko rapidfuzz setuptools sexpdata six watchdog
  ]);
  runtime = pkgs.writeText "lsp-bridge-runtime.el" ''
    ;;; lsp-bridge-runtime.el --- Nix runtime -*- lexical-binding: t; -*-
    ;; Load source directly, as recommended upstream.
    (add-to-list 'load-path "${source}")
    (add-to-list 'load-path "${source}/acm")
    (setq lsp-bridge-python-command "${python}/bin/python3")
    (defvar my/lsp-bridge-python "${python}/bin/python3")
    (defvar my/lsp-bridge-nix "${pkgs.nix}/bin/nix")
  '';
in
{ inherit source python runtime; }

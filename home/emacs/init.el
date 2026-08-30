;;; init.el --- Shared Emacs 31.1 configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Shared by the Nix-built Emacs 31.1 no-X package on macOS and Linux.
;; Third-party packages use Emacs' standard GNU/NonGNU ELPA configuration.

;;; Code:

;; Keep generated customisations below the active XDG/legacy Emacs directory.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))

;; `package.el' automatically activates installed packages before this file is
;; loaded.  `use-package' is built into Emacs and delegates missing package
;; installation to package.el through its standard :ensure integration.
(require 'use-package-ensure)
(setopt use-package-always-ensure t)

;; Fast, quiet defaults for terminal frames and language-server processes.
(setopt inhibit-startup-screen t
        initial-scratch-message nil
        ring-bell-function #'ignore
        use-short-answers t
        auto-save-default t
        scroll-conservatively 101
        mouse-wheel-progressive-speed nil
        fast-but-imprecise-scrolling t
        redisplay-skip-fontification-on-input t
        read-process-output-max (* 1024 1024)
        process-adaptive-read-buffering nil
        auto-revert-use-notify t
        auto-revert-avoid-polling t
        auto-revert-verbose t
        recentf-auto-cleanup 'never
        completion-cycle-threshold 3
        tab-always-indent 'complete
        display-line-numbers-width-start t)
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))
(column-number-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(global-auto-revert-mode 1)
(global-so-long-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(show-paren-mode 1)
(unless noninteractive
  (xterm-mouse-mode 1))

;; Modus Vivendi starts from an accessibility-oriented dark palette.  Explicit
;; face overrides keep syntax, links, selections, and mode lines readable on
;; both 256-colour and true-colour terminals; notably, nothing important uses
;; the low-luminance dark blue which many terminal palettes render illegibly.
(mapc #'disable-theme custom-enabled-themes)
(load-theme 'modus-vivendi t)
(custom-set-faces
 '(default ((t (:background "#101010" :foreground "#f2f2f2"))))
 '(cursor ((t (:background "#ffffff"))))
 '(shadow ((t (:foreground "#b4b4b4"))))
 '(region ((t (:extend t :background "#5a5a5a" :foreground "#ffffff"))))
 '(secondary-selection
   ((t (:extend t :background "#3a3a3a" :foreground "#ffffff"))))
 '(highlight ((t (:background "#3a3a3a" :foreground "#ffffff"))))
 '(match ((t (:background "#00d3d0" :foreground "#000000" :weight bold))))
 '(minibuffer-prompt ((t (:foreground "#6ae4b9" :weight bold))))
 '(link ((t (:foreground "#00d3d0" :underline t))))
 '(link-visited ((t (:foreground "#f78fe7" :underline t))))
 '(button ((t (:foreground "#00d3d0" :underline t))))
 '(font-lock-builtin-face ((t (:foreground "#f0ce7d"))))
 '(font-lock-comment-face ((t (:foreground "#b4b4b4" :slant italic))))
 '(font-lock-comment-delimiter-face ((t (:foreground "#989898"))))
 '(font-lock-constant-face ((t (:foreground "#00d3d0"))))
 '(font-lock-doc-face ((t (:foreground "#d2b580"))))
 '(font-lock-function-name-face ((t (:foreground "#feacd0" :weight bold))))
 '(font-lock-keyword-face ((t (:foreground "#ff9f80" :weight bold))))
 '(font-lock-negation-char-face ((t (:foreground "#ff5f59" :weight bold))))
 '(font-lock-preprocessor-face ((t (:foreground "#f0ce7d"))))
 '(font-lock-string-face ((t (:foreground "#a8e6a3"))))
 '(font-lock-type-face ((t (:foreground "#6ae4b9"))))
 '(font-lock-variable-name-face ((t (:foreground "#fbd6f4"))))
 '(font-lock-warning-face ((t (:foreground "#ff5f59" :weight bold))))
 '(error ((t (:foreground "#ff5f59" :weight bold))))
 '(warning ((t (:foreground "#ff9f80" :weight bold))))
 '(success ((t (:foreground "#6ae4b9" :weight bold))))
 '(isearch ((t (:background "#f0ce7d" :foreground "#000000" :weight bold))))
 '(lazy-highlight ((t (:background "#00d3d0" :foreground "#000000"))))
 '(show-paren-match ((t (:background "#6ae4b9" :foreground "#000000" :weight bold))))
 '(show-paren-mismatch ((t (:background "#ff5f59" :foreground "#000000" :weight bold))))
 '(line-number ((t (:background "#1e1e1e" :foreground "#989898"))))
 '(line-number-current-line
   ((t (:background "#303030" :foreground "#ffffff" :weight bold))))
 '(mode-line ((t (:background "#f0ce7d" :foreground "#000000" :box nil :weight bold))))
 '(mode-line-inactive ((t (:background "#303030" :foreground "#b4b4b4" :box nil))))
 '(header-line ((t (:background "#303030" :foreground "#f2f2f2" :box nil))))
 '(vertical-border ((t (:foreground "#5a5a5a"))))
 '(trailing-whitespace ((t (:background "#ff5f59")))))

;; Programs using ANSI colour 34 often request an unreadably dark blue.  Map
;; that slot to a light blue and keep every other standard colour high contrast.
(with-eval-after-load 'ansi-color
  (setopt ansi-color-names-vector
          ["#1e1e1e" "#ff5f59" "#6ae4b9" "#f0ce7d"
           "#79a8ff" "#f78fe7" "#00d3d0" "#f2f2f2"]))

;; Evil must see these variables before it is loaded.
(setopt evil-want-C-u-scroll t
        evil-want-C-i-jump nil
        evil-undo-system 'undo-redo)

(use-package evil
  :functions evil-mode
  :config
  (evil-mode 1))

;; Emacs 31+ implements child frames on text terminals.  Corfu 2.x detects
;; `tty-child-frames' itself, so Emacs 31.1 needs no `corfu-terminal' fallback.
(use-package corfu
  :demand t
  :functions (global-corfu-mode corfu-history-mode corfu-popupinfo-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  ;; Evil's Ex prompt has its own specialised completion-at-point functions.
  ;; Corfu auto-completion in that minibuffer corrupts Evil's text properties.
  (global-corfu-minibuffer nil)
  (corfu-preselect 'prompt)
  (corfu-preview-current 'insert)
  :config
  (global-corfu-mode 1)
  (corfu-history-mode 1)
  (corfu-popupinfo-mode 1))

(use-package magit
  :commands (magit-status magit-dispatch)
  :bind (("C-x g" . magit-status)))

(use-package slime
  :commands slime
  :init
  (setq inferior-lisp-program (or (executable-find "sbcl") "sbcl")
        slime-contribs '(slime-fancy)))

;; nix-mode compiles optional Company and MMM integration modules without
;; declaring those dependencies in its ELPA metadata.  Install them first; they
;; remain unloaded unless another package requests them.
(use-package company
  :defer t)

(use-package mmm-mode
  :defer t)

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package eglot
  :ensure nil
  :commands (eglot eglot-ensure)
  :hook ((c-mode c++-mode c-ts-mode c++-ts-mode
          python-mode python-ts-mode
          rust-ts-mode
          js-mode js-ts-mode typescript-ts-mode tsx-ts-mode
          sh-mode bash-ts-mode
          nix-mode)
         . eglot-ensure)
  :custom
  (eglot-autoshutdown t)
  (eglot-sync-connect nil)
  :config
  (add-to-list 'eglot-server-programs '(nix-mode . ("nixd"))))

(use-package tramp
  :ensure nil
  :defer t
  :custom
  (tramp-default-method "ssh")
  (tramp-verbose 1))

(use-package which-key
  :ensure nil
  :custom
  (which-key-idle-delay 0.4)
  :config
  (which-key-mode 1))

(provide 'init)
;;; init.el ends here

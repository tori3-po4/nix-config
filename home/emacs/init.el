;;; init.el --- Shared Emacs 31.1 configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Shared by Homebrew Emacs Plus on macOS and Nix-built Emacs 31.1 PGTK on Linux.
;; Prefer GNU/NonGNU ELPA; Evil uses NonGNU-devel, LSP packages use MELPA.

;;; Code:

;; Keep generated customisations below the active XDG/legacy Emacs directory.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))

;; Let GUI Emacs find Nix itself as well as user-installed language servers.
(when (eq system-type 'darwin)
  (dolist (nix-bin (list "/run/current-system/sw/bin"
                       (format "/etc/profiles/per-user/%s/bin" (user-login-name))))
    (when (file-directory-p nix-bin)
      (add-to-list 'exec-path nix-bin)
      (setenv "PATH"
	      (concat nix-bin path-separator (getenv "PATH"))))))

;; Use the Nix zsh on PATH for interactive shells, including Eat.
(setq explicit-shell-file-name (executable-find "zsh"))

;; Keep crash-recovery files without scattering `#file#' entries next to the
;; files being edited.
(let ((auto-save-dir
       (expand-file-name "auto-save/" user-emacs-directory)))
  (make-directory auto-save-dir t)
  (setq auto-save-file-name-transforms
        `((".*" ,auto-save-dir t))))

(let ((backup-dir
       (expand-file-name "backup/" user-emacs-directory)))
  (make-directory backup-dir t)
  (setq backup-directory-alist
        `((".*" . ,backup-dir))))

;; `package.el' automatically activates installed packages before this file is
;; loaded.  `use-package' is built into Emacs and delegates missing package
;; installation to package.el through its standard :ensure integration.
(require 'package)
(add-to-list 'package-archives
             '("nongnu-devel" . "https://elpa.nongnu.org/nongnu-devel/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Prefer stable packages unless an individual package explicitly pins devel.
(setopt package-archive-priorities
        '(("gnu" . 30) ("nongnu" . 20) ("nongnu-devel" . 10) ("melpa" . 0)))
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
        display-line-numbers-width-start t
	tab-bar-show t )
(setq-default truncate-lines t)
(menu-bar-mode 1)
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
(tab-bar-mode 1)

;;define command to search web by google
(require 'xwidget)
(require 'url-util)

(defun google (query)
  "googleでqueryを検索してxwidgetで表示する"
  (interactive (list (read-string "Google検索: ")))
  (xwidget-webkit-browse-url
   (concat "https://www.google.com/search?q="
           (url-hexify-string query))))

(global-set-key (kbd "C-c u") #'universal-argument)

;; This warm light preset resembles Zed's Gruvbox Light Soft.  Let the theme
;; control faces and ANSI colours, and update it independently through GNU ELPA.
(use-package modus-themes
  :ensure t
  :pin gnu
  :demand t
  :config
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'modus-operandi-tinted t))

;; Evil must see these variables before it is loaded.
(setopt evil-want-C-u-scroll t
        evil-want-C-i-jump nil
        evil-undo-system 'undo-redo)

(use-package evil
  :pin nongnu-devel
  :functions evil-mode
  :init
  ;; Stable Evil 1.15.0 references the obsolete `evil-mode-buffers' variable.
  ;; :ensure alone accepts an installed stable version, so upgrade it before
  ;; loading Evil.  This known-good devel version is a minimum, not a lock.
  (unless (package-installed-p 'evil '(1 15 0 0 20260728 297))
    (package-refresh-contents)
    (let ((evil-devel (package-get-descriptor 'evil 'archive)))
      (unless (and evil-devel
                   (equal (package-desc-archive evil-devel) "nongnu-devel")
                   (not (version-list-< (package-desc-version evil-devel)
                                       '(1 15 0 0 20260728 297))))
        (error "A compatible Evil build is unavailable from NonGNU-devel"))
      (package-install evil-devel)))
  :config
  (evil-mode 1))

;; Emacs 31+ implements child frames on text terminals.  Corfu 2.x detects
;; `tty-child-frames' itself, so Emacs 31.1 needs no `corfu-terminal' fallback.
(use-package corfu
  :demand t
  :functions (global-corfu-mode corfu-history-mode corfu-popupinfo-mode)
  :custom
  (corfu-auto t)
  ;; Avoid requesting large candidate sets after every single character.
  ;; Manual completion (M-TAB) remains available before this threshold.
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  ;; Member access such as person. should not wait for two more characters.
  (corfu-auto-trigger ".")
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

(use-package vertico
  :init
  (vertico-mode 1))

(use-package magit
  :commands (magit-status magit-dispatch)
  :bind (("C-x g" . magit-status)))

;; Show Git changes beside each line in both GUI and terminal frames.
;; GNU ELPA retires old .tar files.  Refresh before the first installation;
;; :ensure otherwise reuses a cached version even when its download is gone.
(unless (package-installed-p 'diff-hl)
  (package-refresh-contents))

(use-package diff-hl
  :ensure t
  :pin gnu
  :demand t
  :hook (magit-post-refresh . diff-hl-magit-post-refresh)
  :config
  (diff-hl-margin-mode 1)
  (global-diff-hl-mode 1)
  ;; Include edits that have not been saved to disk yet.
  (diff-hl-flydiff-mode 1))

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

;; Emacs 31 supplies grammar sources, downloads and mode remapping itself.
(use-package treesit
  :ensure nil
  :demand t
  :custom
  (treesit-enabled-modes t)
  (treesit-auto-install-grammar 'always))

(use-package web-mode
  :pin nongnu
  :mode "\\.astro\\'")

(use-package yasnippet
  ;; LSP completion items may contain snippets, including HTML attributes.
  :hook (lsp-mode . yas-minor-mode))

(use-package lsp-mode
  :pin melpa
  :demand t
  :commands (lsp lsp-deferred)
  :hook ((c-mode c++-mode c-ts-mode c++-ts-mode
          python-mode python-ts-mode
          rust-ts-mode
          js-mode js-ts-mode typescript-ts-mode tsx-ts-mode
	  html-mode mhtml-mode html-ts-mode css-mode css-ts-mode
          sh-mode bash-ts-mode
          nix-mode nix-ts-mode)
         . lsp-deferred)
  :custom
  ;; Keep the LSP CAPF for Corfu without automatically starting Company.
  (lsp-completion-provider :none)
  (lsp-completion-no-cache nil)
  (lsp-completion-use-last-result t)
  (lsp-diagnostics-provider :flymake)
  (lsp-log-io nil)
  (lsp-auto-guess-root t)
  ;; Keep the existing nixd choice, including automatically registered TRAMP clients.
  (lsp-disabled-clients '(rnix-lsp nix-nil rnix-lsp-tramp nix-nil-tramp))
  :config
  (unless (and lsp-use-plists
               (equal (lsp-make-position :line 0 :character 0)
                      '(:line 0 :character 0)))
    (error "Rebuild lsp-mode with LSP_USE_PLISTS=true; see early-init.el"))
  ;; Match the extension before web-mode's generic HTML language ID.
  (add-to-list 'lsp-language-id-configuration '("\\.astro\\'" . "astro")))

(use-package lsp-pyright
  :pin melpa
  :demand t)

(use-package lsp-ruff
  :ensure nil ; Included in lsp-mode; Ruff is an add-on to Pyright.
  :demand t)

(defun my-lsp-astro-maybe ()
  "Start Astro and applicable add-on servers for an Astro web-mode buffer."
  (when (and buffer-file-name (string-match-p "\\.astro\\'" buffer-file-name))
    (lsp-deferred)))

(use-package lsp-astro
  :ensure nil
  :demand t
  :hook (web-mode . my-lsp-astro-maybe)
  :config
  (defun my-lsp-astro-server-sdk-path (options)
    "Use a server-local TypeScript SDK path in OPTIONS, including over TRAMP."
    (when-let* ((typescript (plist-get options :typescript))
                (sdk (plist-get typescript :tsdk)))
      (plist-put typescript :tsdk (file-local-name sdk)))
    options)
  (advice-add 'lsp-astro--get-initialization-options :filter-return
              #'my-lsp-astro-server-sdk-path))

(use-package lsp-tailwindcss
  :ensure nil
  :demand t
  :config
  (defun my-lsp-tailwindcss-v4-activation (original &rest args)
    "Recognize Tailwind v4 before the first workspace has been registered."
    (or (apply original args)
        (and buffer-file-name
             (apply #'provided-mode-derived-p major-mode lsp-tailwindcss-major-modes)
             (lsp-tailwindcss--version-v4-p))))
  (advice-add 'lsp-tailwindcss--activate-p :around
              #'my-lsp-tailwindcss-v4-activation)
  ;; Invoke the Nix executable directly, using its own Node interpreter.
  (let ((client (gethash 'tailwindcss lsp-clients)))
    (setf (lsp--client-new-connection client)
          (lsp-stdio-connection '("tailwindcss-language-server" "--stdio")))
    ;; Also refresh the automatically generated TRAMP client.
    (lsp-register-client client))
  (defun my-lsp-tailwindcss-dash-when-supported (original workspace)
    "Run ORIGINAL only when WORKSPACE advertises completion at initialization."
    ;; Tailwind 0.14.29 registers completion dynamically. The stock workaround
    ;; otherwise fails on its initial capabilities, before didOpen is sent.
    (when (plist-get (lsp--workspace-server-capabilities workspace) :completionProvider)
      (funcall original workspace)))
  (advice-add 'lsp-tailwindcss--company-dash-hack :around
              #'my-lsp-tailwindcss-dash-when-supported))

(use-package lsp-eslint
  :ensure nil
  :demand t
  :custom
  (lsp-eslint-server-command '("vscode-eslint-language-server" "--stdio"))
  (lsp-eslint-trace-server "off")
  :config
  (add-to-list 'lsp-eslint-validate "astro")
  ;; Preserve the built-in JS/TS activation rules and add Astro.
  (let* ((client (gethash 'eslint lsp-clients))
         (activate (lsp--client-activation-fn client)))
    (setf (lsp--client-activation-fn client)
          (lambda (filename mode)
            (and lsp-eslint-enable
                 (or (and filename (string-match-p "\\.astro\\'" filename))
                     (funcall activate filename mode)))))
    (lsp-register-client client)))

(defun lsp-nix (directory command)
  "Start COMMAND with lsp-mode in DIRECTORY's Nix development environment."
  (interactive "DNix development directory: \nsLSP command: ")
  (let* ((directory (expand-file-name directory))
         (server-id (intern (concat "nix-develop-"
                                    (secure-hash 'sha256
                                                 (format "%S" (list major-mode directory command)))))))
    (lsp-register-client
     (make-lsp-client
      :new-connection (lsp-stdio-connection
                       (list "nix" "develop" (file-local-name directory)
                             "-c" "/bin/sh" "-c" (concat "exec " command)))
      :major-modes (list major-mode)
      :remote? (and (file-remote-p directory) t)
      :server-id server-id))
    (when (bound-and-true-p lsp-mode) (lsp-disconnect))
    (setq-local lsp-enabled-clients (list server-id))
    (lsp)))

(use-package tramp
  :ensure nil
  :defer t
  :custom
  (tramp-default-method "ssh")
  (tramp-verbose 1))

(use-package which-key
  :ensure nil
  :demand t
  :bind (("M-SPC" . which-key-show-top-level))
  :custom
  (which-key-idle-delay 0.4)
  :config
  (which-key-mode 1))
(use-package eat
  :pin nongnu
  :commands eat
  :custom
  (eat-minimum-latency 0.05)
  (eat-maximum-latency 0.15)
  ;; Eat 0.9.4 redraws the whole frame on every cursor blink.  A TUI's
  ;; blinking cursor can persist after it exits back to the shell.
  (eat-very-visible-cursor-type '(box nil nil))
  (eat-very-visible-vertical-bar-cursor-type '(bar nil nil))
  (eat-very-visible-horizontal-bar-cursor-type '(hbar nil nil))
  :init
  ;; EATのキー入力をevilが横取りしないようにする。
  (with-eval-after-load 'evil
    (evil-set-initial-state 'eat-mode 'emacs)))

(provide 'init)
;;; init.el ends here

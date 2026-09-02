;;; init.el --- Shared Emacs 31.1 configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Shared by Homebrew Emacs Plus on macOS and Nix-built Emacs 31.1 PGTK on Linux.
;; Third-party packages use GNU/NonGNU ELPA, with Evil pinned to NonGNU-devel.

;;; Code:

;; Keep generated customisations below the active XDG/legacy Emacs directory.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))

;;make emacs able to find lsp
(when (eq system-type 'darwin)
  (let ((nix-bin (format "/etc/profiles/per-user/%s/bin" (user-login-name))))
    (when (file-directory-p nix-bin)
      (add-to-list 'exec-path nix-bin)
      (setenv "PATH"
	      (concat nix-bin path-separator (getenv "PATH"))))))


;; Keep crash-recovery files without scattering `#file#' entries next to the
;; files being edited.
(let ((auto-save-dir
       (expand-file-name "auto-save/" user-emacs-directory)))
  (make-directory auto-save-dir t)
  (setq auto-save-file-name-transforms
        `((".*" ,auto-save-dir t))))

;; `package.el' automatically activates installed packages before this file is
;; loaded.  `use-package' is built into Emacs and delegates missing package
;; installation to package.el through its standard :ensure integration.
(require 'package)
(add-to-list 'package-archives
             '("nongnu-devel" . "https://elpa.nongnu.org/nongnu-devel/") t)
;; Prefer stable packages unless an individual package explicitly pins devel.
(setopt package-archive-priorities
        '(("gnu" . 30) ("nongnu" . 20) ("nongnu-devel" . 10)))
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
(setq-default truncate-lines t)
(menu-bar-mode 1)
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode 1))
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
  (which-key-mode 1)
  ;; Space displays the current bindings immediately in Evil's command states.
  (with-eval-after-load 'evil
    (evil-define-key '(normal visual) 'global
      (kbd "SPC") #'which-key-show-top-level)))

(provide 'init)
;;; init.el ends here

;;; init.el --- Shared Emacs 32 configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Shared by Emacs Plus on macOS and emacs-git-pgtk on Linux.
;; Third-party packages intentionally come only from GNU ELPA and NonGNU ELPA.

;;; Code:

(require 'seq)

;; Keep package data and Custom output below the active Emacs directory.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory)
      package-native-compile t
      native-comp-async-report-warnings-errors 'silent)
(when (file-readable-p custom-file)
  (load custom-file nil 'nomessage))

;; Emacs Plus casks are launched by macOS with a minimal PATH.  Add the
;; declarative Nix/Homebrew locations without invoking an interactive shell.
(let* ((managed-paths
        (seq-filter
         #'file-directory-p
         (list (expand-file-name ".local/bin" "~")
               (expand-file-name ".nix-profile/bin" "~")
               (format "/etc/profiles/per-user/%s/bin" user-login-name)
               "/run/current-system/sw/bin"
               "/opt/homebrew/bin"
               "/usr/local/bin")))
       (environment-paths
        (split-string (or (getenv "PATH") "") path-separator t)))
  (setq exec-path (delete-dups (append managed-paths exec-path))
        process-environment (copy-sequence process-environment))
  (setenv "PATH"
          (string-join (delete-dups (append managed-paths environment-paths))
                       path-separator)))

;; GNU ELPA takes precedence where the same dependency exists in both archives.
;; The requested packages are all available from these signed upstream archives,
;; so MELPA is deliberately unnecessary.
(require 'package)
(setq package-archives
      '(("gnu" . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/"))
      package-archive-priorities
      '(("gnu" . 20)
        ("nongnu" . 10))
      package-selected-packages
      '(evil corfu magit slime eglot tramp which-key nix-mode))
(package-initialize)

(defun my/package-install-required ()
  "Install missing packages from GNU ELPA or NonGNU ELPA.
Built-in packages such as Eglot, TRAMP, and which-key count as installed."
  (let ((missing (seq-remove #'package-installed-p package-selected-packages)))
    (when missing
      (condition-case error-data
          (progn
            (package-refresh-contents)
            (dolist (package missing)
              (unless (package-installed-p package)
                (package-install package))))
        (error
         (display-warning
          'emacs-init
          (format "ELPA package bootstrap failed: %s"
                  (error-message-string error-data))
          :error))))))

(my/package-install-required)
(require 'use-package)

;; Fast, quiet defaults which behave consistently in GUI and terminal frames.
(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore
      use-short-answers t
      auto-save-default t
      scroll-conservatively 101
      mouse-wheel-progressive-speed nil)
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))
(column-number-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(global-auto-revert-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(show-paren-mode 1)

;; Evil must see these variables before it is loaded.
(setq evil-want-C-u-scroll t
      evil-want-C-i-jump nil
      evil-undo-system 'undo-redo)
(use-package evil
  :if (package-installed-p 'evil)
  :config
  (evil-mode 1))

;; Emacs 31+ implements child frames on text terminals.  Corfu 2.x detects
;; `tty-child-frames' itself, so Emacs 32 uses the same popup UI in GUI and TUI.
(use-package corfu
  :if (package-installed-p 'corfu)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preview-current 'insert)
  :init
  (global-corfu-mode 1)
  :config
  (corfu-popupinfo-mode 1))

(use-package magit
  :if (package-installed-p 'magit)
  :commands (magit-status magit-dispatch)
  :bind (("C-x g" . magit-status)))

(use-package slime
  :if (package-installed-p 'slime)
  :commands slime
  :init
  (setq inferior-lisp-program (or (executable-find "sbcl") "sbcl")
        slime-contribs '(slime-fancy)))

;; Keep Nix editing and its language server usable in this repository.
(use-package nix-mode
  :if (package-installed-p 'nix-mode)
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

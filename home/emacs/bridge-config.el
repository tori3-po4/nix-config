;;; bridge-config.el --- lsp-bridge and ACM integration -*- lexical-binding: t; -*-
;; The Nix-generated runtime pins the source and its isolated Python environment.
(load (expand-file-name "lsp-bridge-runtime.el" user-emacs-directory) nil 'nomessage)

(require 'lsp-bridge)
(setq lsp-bridge-user-langserver-dir
      (expand-file-name "lsp-bridge/langserver" user-emacs-directory)
      lsp-bridge-user-multiserver-dir
      (expand-file-name "lsp-bridge/multiserver" user-emacs-directory)
      lsp-bridge-python-lsp-server "pyright"
      lsp-bridge-python-multi-lsp-server "pyright_ruff"
      lsp-bridge-nix-lsp-server "nixd"
      lsp-bridge-log-level 'warning
      lsp-bridge-enable-debug nil
      lsp-bridge-enable-search-words nil
      acm-enable-search-file-words nil
      acm-enable-ctags nil
      acm-enable-tabnine nil
      acm-enable-copilot nil
      acm-enable-codeium nil
      acm-enable-capf t
      acm-enable-icon nil
      acm-enable-preview nil
      acm-backend-lsp-candidates-max-number 100)
(add-to-list 'lsp-bridge-completion-in-string-file-types "astro")
(add-to-list 'lsp-bridge-multi-lang-server-extension-list
             '(("astro") . "astro_tailwindcss_eslint"))

(defun my/lsp-bridge-popup-p ()
  "Show automatic completion after two characters or a member-access dot."
  (let* ((acm-input-bound-style "ascii")
         (bounds (acm-get-input-prefix-bound)))
    (or lsp-bridge-manual-complete-flag
        (>= (length (acm-get-input-prefix)) 2)
        (eq (char-before) ?.)
        (and bounds (eq (char-before (car bounds)) ?.)))))
(add-to-list 'lsp-bridge-completion-popup-predicates #'my/lsp-bridge-popup-p)

;; Eglot/Company/Corfu must not compete with ACM for completion or keymaps.
(defun my/lsp-bridge-buffer-setup ()
  (when (bound-and-true-p corfu-mode) (corfu-mode -1))
  (when (bound-and-true-p company-mode) (company-mode -1))
  (when (bound-and-true-p flymake-mode) (flymake-mode -1)))
(add-hook 'lsp-bridge-mode-hook #'my/lsp-bridge-buffer-setup)

(define-key lsp-bridge-mode-map (kbd "M-TAB") #'lsp-bridge-popup-complete-menu)
(define-key lsp-bridge-mode-map (kbd "M-.") #'lsp-bridge-find-def)
(define-key lsp-bridge-mode-map (kbd "M-,") #'lsp-bridge-find-def-return)
(define-key lsp-bridge-mode-map (kbd "C-c l d") #'lsp-bridge-find-def)
(define-key lsp-bridge-mode-map (kbd "C-c l r") #'lsp-bridge-rename)
(define-key lsp-bridge-mode-map (kbd "C-c l a") #'lsp-bridge-code-action)
(define-key lsp-bridge-mode-map (kbd "C-c l f") #'lsp-bridge-code-format)
(define-key lsp-bridge-mode-map (kbd "C-c l e") #'lsp-bridge-diagnostic-list)
(define-key lsp-bridge-mode-map (kbd "C-c l h") #'lsp-bridge-popup-documentation)
(define-key lsp-bridge-mode-map (kbd "C-c l R") #'lsp-bridge-restart-process)
(define-key acm-mode-map (kbd "C-n") #'acm-select-next)
(define-key acm-mode-map (kbd "C-p") #'acm-select-prev)
(define-key acm-mode-map (kbd "TAB") #'acm-complete)
(define-key acm-mode-map (kbd "RET") #'acm-complete)
(define-key acm-mode-map (kbd "C-g") #'acm-hide)
(with-eval-after-load 'evil
  (evil-define-key 'normal lsp-bridge-mode-map
    (kbd "g d") #'lsp-bridge-find-def
    (kbd "g r") #'lsp-bridge-find-references
    (kbd "K") #'lsp-bridge-popup-documentation))

(defun lsp ()
  "Enable lsp-bridge in the current buffer."
  (interactive)
  (lsp-bridge-mode 1)
  (lsp-bridge-start-process))

(defvar my/lsp-bridge-nix-wrapper nil)
(defun lsp-nix (directory)
  "Restart the shared lsp-bridge backend inside DIRECTORY's Nix dev shell.
This switches the environment for ALL lsp-bridge buffers, because the
Python backend is shared.  Shell hooks and Nix's environment handling are
preserved.  Use `lsp-host' to return to the normal environment."
  (interactive "DNix development directory for all LSP buffers: ")
  (when (file-remote-p directory)
    (user-error "lsp-nix supports local development environments only"))
  (let ((wrapper (make-temp-file "lsp-bridge-nix-")))
    (with-temp-file wrapper
      (insert "#!/bin/sh\nexec " (shell-quote-argument my/lsp-bridge-nix)
              " develop " (shell-quote-argument (expand-file-name directory))
              " --command " (shell-quote-argument my/lsp-bridge-python) " \"$@\"\n"))
    (set-file-modes wrapper #o700)
    (setq lsp-bridge-python-command wrapper)
    (lsp-bridge-mode 1)
    (lsp-bridge-restart-process)
    (when my/lsp-bridge-nix-wrapper (delete-file my/lsp-bridge-nix-wrapper))
    (setq my/lsp-bridge-nix-wrapper wrapper)))

(defun lsp-host ()
  "Restart all lsp-bridge servers using the normal Nix-managed Python."
  (interactive)
  (setq lsp-bridge-python-command my/lsp-bridge-python)
  (lsp-bridge-restart-process)
  (when my/lsp-bridge-nix-wrapper
    (delete-file my/lsp-bridge-nix-wrapper)
    (setq my/lsp-bridge-nix-wrapper nil)))

(dolist (hook '(html-mode-hook mhtml-mode-hook html-ts-mode-hook
               slime-repl-mode-hook))
  (add-to-list 'lsp-bridge-default-mode-hooks hook))
(add-to-list 'acm-backend-capf-mode-list 'slime-repl-mode)
(global-lsp-bridge-mode)
(provide 'bridge-config)
;;; bridge-config.el ends here

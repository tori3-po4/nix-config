;;; early-init.el --- Early startup settings for terminal Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep package activation and avoidable garbage collection out of the part of
;; startup which runs before init.el.  init.el restores conservative GC values.

;;; Code:

;; Emacs activates packages after early-init.el and before init.el.  Select the
;; versioned package and quickstart paths here so that the standard activation
;; uses only artifacts produced by this Emacs major version.
(setopt package-user-dir
        (expand-file-name (format "elpa/%d" emacs-major-version)
                          user-emacs-directory)
        package-quickstart-file
        (expand-file-name (format "package-quickstart-%d.el"
                                  emacs-major-version)
                          user-emacs-directory)
        package-quickstart t)

(setq gc-cons-threshold (* 128 1024 1024)
      gc-cons-percentage 0.6)

;; These modes have no useful rendering in a text frame.  Disabling them here
;; also avoids frame setup work before init.el is read.
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

(provide 'early-init)
;;; early-init.el ends here

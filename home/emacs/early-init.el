;;; early-init.el --- Early startup settings for terminal Emacs -*- lexical-binding: t; -*-

;;; Commentary:
;; Keep package activation and avoidable garbage collection out of the part of
;; startup which runs before init.el.  init.el restores conservative GC values.

;;; Code:

;; init.el performs one explicit package activation after configuring the
;; GNU/NonGNU archives and package quickstart cache.
(setq package-enable-at-startup nil
      gc-cons-threshold (* 128 1024 1024)
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

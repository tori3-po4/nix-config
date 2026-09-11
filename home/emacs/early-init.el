;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-

;; lsp-mode must use the same representation when compiled and when loaded.
;; Set this before package.el activates packages or compiles new installations.
(setenv "LSP_USE_PLISTS" "true")

;; 起動時の GC 回数を抑える。
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; GUI フレーム生成時の余分なリサイズを抑える。
(setq frame-inhibit-implied-resize t
      inhibit-compacting-font-caches t)

;; 起動後は Astro/Tailwind/ESLint の補完計測で確認した値へ戻す。
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1)))

(add-to-list 'default-frame-alist '(fullscreen . fullboth))
;;; early-init.el ends here

;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-

;; 起動時の GC 回数を抑える。
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; GUI フレーム生成時の余分なリサイズを抑える。
(setq frame-inhibit-implied-resize t
      inhibit-compacting-font-caches t)

;; 起動後は通常利用向けの値へ戻す。
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1)))

;;; early-init.el ends here

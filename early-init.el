;;; early-init.el --- Emacs 27+ pre-initialisation config

;;; Commentary:

;; Emacs 27+ loads this file before (normally) calling
;; `package-initialize'.  We use this file to suppress that automatic
;; behaviour so that startup is consistent across Emacs versions.

;;; Code:

(setq package-enable-at-startup nil)

;; ---- native-comp: defer all JIT compilation to after startup ----
;; Prevents "Too many open files" on first launch (Windows pipe limit).
;; Compiled .eln files will be cached after first run; subsequent startups are fast.
(setq native-comp-jit-compilation nil)
(setq native-comp-async-jobs-number 1)
(setq inhibit-automatic-native-compilation t)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq inhibit-automatic-native-compilation nil)
            (setq native-comp-jit-compilation t)
            (setq native-comp-async-jobs-number 2)))

;; ---- Performance: suppress GUI work during init ----
(setq frame-inhibit-implied-resize t)  ; don't resize frame for font changes
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; ---- Performance: GC pause during init ----
;; Raise threshold to 128MB during init; gcmh will manage it after.
(setq gc-cons-threshold (* 128 1024 1024))
(setq gc-cons-percentage 0.6)

;; ---- Performance: suppress file-handler matching during init ----
(defvar my/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist my/file-name-handler-alist)))

;; So we can detect this having been loaded
(provide 'early-init)

;;; early-init.el ends here

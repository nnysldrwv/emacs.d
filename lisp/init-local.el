;;; init-local.el --- Sean's personal customizations on top of purcell/emacs.d -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; This file is loaded at the end of init.el (purcell convention).
;; It contains all of Sean's personal configurations that extend or
;; override purcell defaults.
;;
;;; Code:

;; ============================================================
;;  1. Fonts — Maple Mono NF CN (中英等宽，自带 CJK + Nerd Font)
;; ============================================================

(defun my/first-available-font (candidates)
  "Return the first font family from CANDIDATES that is available."
  (catch 'found
    (dolist (font candidates)
      (when (find-font (font-spec :family font))
        (throw 'found font)))
    nil))

(defun my/setup-fonts (&optional frame)
  "Configure fonts. Works for both normal start and daemon+emacsclient.
When called from `after-make-frame-functions', FRAME is the new frame."
  (when frame (select-frame frame))
  (when (display-graphic-p)
    ;; Default font — prefer Maple Mono (built-in CJK, no rescale needed)
    (let ((default-font (my/first-available-font
                         '("Maple Mono NF CN"
                           "Cascadia Code" "SF Mono" "Menlo" "Consolas"))))
      (when default-font
        (set-face-attribute 'default nil :family default-font :height 120)))

    ;; Variable-pitch face (used by shr/elfeed for reading)
    (let ((vp-font (my/first-available-font
                    '("霞鹜文楷" "Microsoft YaHei UI" "Sarasa Gothic SC" "Noto Sans SC" "Segoe UI" "Arial"))))
      (when vp-font
        (set-face-attribute 'variable-pitch nil :family vp-font)))

    ;; CJK fallback — explicit mapping for better rendering
    (let ((cjk-font (my/first-available-font
                     '("霞鹜文楷等宽" "等距更纱黑体 SC"
                       "LXGW WenKai Mono" "Sarasa Mono SC"
                       "Noto Sans SC" "Microsoft YaHei UI"))))
      (when cjk-font
        (dolist (charset '(kana han cjk-misc bopomofo))
          (set-fontset-font t charset (font-spec :family cjk-font) nil 'prepend))))

    ;; Emoji & Symbol
    (let ((emoji-font (my/first-available-font
                       '("Segoe UI Emoji" "Apple Color Emoji" "Noto Color Emoji")))
          (symbol-font (my/first-available-font
                        '("Segoe UI Symbol" "Apple Symbols" "Symbola"))))
      (when emoji-font
        (set-fontset-font t 'emoji (font-spec :family emoji-font) nil 'prepend))
      (when symbol-font
        (set-fontset-font t 'symbol (font-spec :family symbol-font) nil 'prepend)))

    ;; Only need to run once — remove hook after first GUI frame
    (remove-hook 'after-make-frame-functions #'my/setup-fonts)))

;; Normal start: apply now; daemon: apply when first frame is created
(if (daemonp)
    (add-hook 'after-make-frame-functions #'my/setup-fonts)
  (my/setup-fonts))

;; ============================================================
;;  2. General overrides + Windows performance tuning
;; ============================================================

;; Light theme (override purcell's default dark theme)
(setq-default custom-enabled-themes '(tsdh-light))

(setq system-time-locale "C")

(save-place-mode 1)

;; Soft word-wrap everywhere (no mid-word breaks)
(global-visual-line-mode 1)

;; Desktop save/restore — disabled
(desktop-save-mode -1)
(advice-add 'desktop-read :override #'ignore)
(setq desktop-auto-save-timeout nil)   ; 停掉 autosave 定时器

;; Faster which-key (purcell default is 1.5s)
(setq-default which-key-idle-delay 0.5)

;; ---- Windows-specific performance ----
(when (eq system-type 'windows-nt)
  ;; Taskbar: set AppUserModelID so pinned shortcut merges with window
  (add-to-list 'load-path (expand-file-name "modules" user-emacs-directory))
  (when (require 'w32-appid nil t)
    (w32-set-app-user-model-id "GNU.Emacs"))

  ;; VC / Git — #1 cause of sluggishness on Windows
  (setq auto-revert-check-vc-info nil)   ; don't check git on every revert
  (setq auto-revert-interval 10)         ; slower polling (default 5s)
  (setq vc-handled-backends '(Git))      ; only Git, skip SVN/Hg/etc
  (setq vc-git-annotate-switches "-w")   ; skip whitespace in blame

  ;; Process creation is expensive on Windows (no fork())
  (setq w32-pipe-read-delay 0)           ; don't sleep between pipe reads
  (setq w32-pipe-buffer-size (* 64 1024)) ; 64KB pipe buffer (default 4KB)
  (setq process-adaptive-read-buffering nil) ; disable adaptive buffering

  ;; File I/O
  (setq inhibit-compacting-font-caches t)    ; CJK font cache GC is very slow
  (setq w32-get-true-file-attributes nil)    ; skip expensive stat() calls
  (setq find-file-visit-truename nil)        ; don't chase symlinks eagerly

  ;; Rendering
  (setq redisplay-skip-fontification-on-input t) ; skip font-lock while typing
  (setq fast-but-imprecise-scrolling t)          ; faster scroll
  (setq jit-lock-defer-time 0.05)               ; defer font-lock 50ms

  ;; Long lines protection (Emacs 29+)
  (when (boundp 'long-line-threshold)
    (setq long-line-threshold 1000)
    (setq large-hscroll-threshold 1000)
    (setq syntax-wholeline-max 1000))

  ;; Disable expensive modes in large files
  (add-hook 'find-file-hook
            (lambda ()
              (when (> (buffer-size) (* 512 1024))  ; >512KB
                (fundamental-mode)
                (font-lock-mode -1)
                (message "⚠ Large file — disabled font-lock"))))

  ;; Magit: use libgit when available, limit diff context
  (with-eval-after-load 'magit
    (setq magit-refresh-status-buffer nil)  ; don't auto-refresh
    (setq magit-diff-refine-hunk nil))      ; skip word-level diff

  ;; Projectile: use alien indexing (external tools) on Windows
  (with-eval-after-load 'projectile
    (setq projectile-indexing-method 'alien)
    (setq projectile-enable-caching t)))

;; ---- GC tuning (all platforms) ----
;; purcell uses gcmh, but we tighten idle threshold
(with-eval-after-load 'gcmh
  (setq gcmh-idle-delay 'auto)
  (setq gcmh-high-cons-threshold (* 64 1024 1024))  ; 64MB during work
  (setq gcmh-low-cons-threshold (* 16 1024 1024)))  ; 16MB when idle

;; Backup / auto-save locations (purcell disables backups; we keep them)
(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups" user-emacs-directory))))
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-saves/" user-emacs-directory) t)))
(make-directory (expand-file-name "auto-saves" user-emacs-directory) t)
(setq make-backup-files t)
(setq auto-save-default t)

;; ============================================================
;;  3. Treemacs sidebar
;; ============================================================

(when (maybe-require-package 'treemacs)
  (setq treemacs-show-hidden-files nil
        treemacs-width 30
        treemacs-is-never-other-window t)
  (global-set-key (kbd "C-c t") 'treemacs)

  ;; Persist sidebar state across restarts
  (defvar my/treemacs-was-visible nil "Whether treemacs was visible before restart.")
  (with-eval-after-load 'desktop
    (add-to-list 'desktop-globals-to-save 'my/treemacs-was-visible))
  (add-hook 'desktop-save-hook
            (lambda ()
              (setq my/treemacs-was-visible
                    (and (fboundp 'treemacs-get-local-window)
                         (treemacs-get-local-window)
                         t))))
  (add-hook 'emacs-startup-hook
            (lambda ()
              (when my/treemacs-was-visible
                (treemacs))))

  (with-eval-after-load 'treemacs
    ;; Smaller font in treemacs buffer (0.85× default size)
    (defun my/treemacs-set-small-font ()
      (require 'face-remap nil t)
      (face-remap-add-relative 'default :height 0.85))
    (add-hook 'treemacs-mode-hook #'my/treemacs-set-small-font)

    (define-key treemacs-mode-map [mouse-1]
                (lambda (event)
                  "Single click to open file / expand dir."
                  (interactive "e")
                  (mouse-set-point event)
                  (treemacs-RET-action)))))

;; ============================================================
;;  4. Restart Emacs (cross-platform)
;; ============================================================

(defun my/restart-emacs ()
  "Restart Emacs cross-platform."
  (interactive)
  (cond
   ((eq system-type 'windows-nt)
    (let ((emacs-bin (expand-file-name "runemacs.exe" invocation-directory)))
      (if (file-exists-p emacs-bin)
          (call-process "cmd.exe" nil 0 nil "/c" "start" "" emacs-bin)
        (start-process "restart-emacs" nil (expand-file-name invocation-name invocation-directory)))))
   ((eq system-type 'darwin)
    (if (executable-find "open")
        (call-process "open" nil 0 nil "-n" "-a" "Emacs")
      (start-process "restart-emacs" nil (expand-file-name invocation-name invocation-directory))))
   (t
    (start-process "restart-emacs" nil (expand-file-name invocation-name invocation-directory))))
  (kill-emacs))

(global-set-key (kbd "C-c q r") #'my/restart-emacs)
(global-set-key (kbd "C-c q q") #'save-buffers-kill-emacs)

;; ============================================================
;;  5. Consult extra bindings (purcell already sets C-x b etc.)
;; ============================================================

(with-eval-after-load 'consult
  (global-set-key (kbd "C-s") 'consult-line)
  (global-set-key (kbd "C-x C-r") 'consult-recent-file)
  (global-set-key (kbd "M-s f") 'consult-find))

;; ============================================================
;;  6. Org-mode — override purcell defaults with Sean's workflow
;; ============================================================

;; ---- Emacs server + org-protocol (must be outside with-eval-after-load) ----
;; Start server if not already running (needed for org-protocol & emacsclient)
(require 'server)
(unless (server-running-p)
  (server-start))

;; Load org-protocol so org-protocol:// URLs are handled by Emacs
(with-eval-after-load 'org
  (require 'org-protocol))

(with-eval-after-load 'org
  ;; org-tempo：启用 <s Tab 等结构模板
  (require 'org-tempo)

  ;; 关掉 ispell，避免 "No plain word-list" 报错
  (setq ispell-program-name nil)

  ;; Directory
  (setq org-directory "~/org")

  ;; Todo keywords — Sean's simplified set
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "|" "DONE(d)" "CANCELLED(c)" "HOLD(h)")))
  (setq org-todo-keyword-faces
        '(("TODO"      :foreground "#2952a3" :weight bold)  ; 深蓝 — 普通待办
          ("NEXT"      :foreground "#c0392b" :weight bold)  ; 朱红 — 立即行动
          ("WAITING"   :foreground "#8b6914" :weight bold)  ; 琥珀 — 等待中
          ("HOLD"      :foreground "#6c6c6c" :weight bold)  ; 中灰 — 搁置
          ("DONE"      :foreground "#2e7d32" :weight bold)  ; 深绿 — 完成
          ("CANCELLED" :foreground "#9e9e9e" :weight bold)))  ; 浅灰 — 取消

  ;; Logging
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)

  ;; Display
  (setq org-confirm-babel-evaluate nil)
  (setq org-src-fontify-natively t)
  (setq org-src-tab-acts-natively t)
  (setq org-return-follows-link t)
  (setq org-startup-indented nil)         ; org-indent via hook below (valign removed)
  (setq org-hide-leading-stars t)         ; hide extra * in headings
  (add-hook 'org-mode-hook 'org-indent-mode)
  (setq org-startup-folded 'content)
  (setq org-hide-emphasis-markers t)
  (setq org-ellipsis " ▾")

  ;; Inline images
  (setq image-use-external-converter t)
  (setq org-image-actual-width '(600))

  ;; Agenda files
  (setq org-agenda-files '("~/org/inbox.org"
                           "~/org/projects/"
                           "~/org/areas/"
                           "~/org/.calendar"))
  (setq org-default-notes-file "~/org/inbox.org")

  ;; Archive
  (setq org-archive-location
        (concat (expand-file-name ".archive/" org-directory)
                "%s_archive.org::"))

  ;; ---- Capture templates ----
  (defun my/journal-file-today ()
    "Return today's journal file path: ~/org/journal/YYYY-MM-DD.org."
    (let* ((date-str (format-time-string "%Y-%m-%d"))
           (file (expand-file-name (concat "journal/" date-str ".org") org-directory)))
      (unless (file-exists-p file)
        (with-temp-file file
          (insert (format "#+title: %s\n#+filetags: :journal:\n\n" date-str))))
      file))

  (setq org-capture-templates
        '(("i" "Inbox" entry (file "~/org/inbox.org")
           "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n" :empty-lines 1)
          ("t" "Task" entry (file "~/org/inbox.org")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n" :empty-lines 1)
          ("j" "Journal" plain (file my/journal-file-today)
           "* %<%H:%M>\n%?"
           :empty-lines 1
           :jump-to-captured t)
          ("r" "Read later" entry (file "~/org/inbox.org")
           "* TODO [[%^{URL}][%^{Title}]]\n:PROPERTIES:\n:CREATED: %U\n:END:\n%?" :empty-lines 1)
          ("m" "Movie" entry (file+headline "~/org/collections/media.org" "观影记录")
           "* %^{片名}\n:PROPERTIES:\n:评分: %^{评分|⭐⭐⭐|⭐⭐⭐⭐|⭐⭐⭐⭐⭐|⭐⭐|⭐}\n:END:\n%U\n%?"
           :empty-lines 1)
          ("w" "Web article" plain (function my/capture-web-article-target)
           "%?"
           :empty-lines 1 :jump-to-captured t)

          ;; ---- org-protocol captures (triggered from browser bookmark) ----
          ;; "pl" = 阅读列表：存到 inbox，标 TODO，一键完成
          ("pl" "Protocol: Read later" entry (file "~/org/inbox.org")
           "* TODO %:annotation\n:PROPERTIES:\n:CREATED: %U\n:END:\n%i\n"
           :immediate-finish t :jump-to-captured t)
          ;; "pn" = 认真读做笔记：存到 references/，与 "w" 模板目标一致
          ;; 用法：可选先选中一段文字，再点书签；引用内容填入 My Notes 节
          ("pn" "Protocol: Note → references/" plain
           (function my/protocol-note-target)
           "#+begin_quote\n%i\n#+end_quote\n%?"
           :jump-to-captured t)))

  ;; ---- Refile targets ----
  (setq my/org-references-files
        (file-expand-wildcards "~/org/references/*.org"))

  (setq org-refile-targets '(("~/org/inbox.org" :maxlevel . 2)
                             ("~/org/projects/project-s.org" :maxlevel . 2)
                             ("~/org/projects/demo.org" :maxlevel . 2)
                             ("~/org/areas/investment.org" :maxlevel . 2)
                             ("~/org/areas/gamedev.org" :maxlevel . 2)
                             ("~/org/areas/ai-agent.org" :maxlevel . 2)
                             (my/org-references-files :maxlevel . 1)))
  (setq org-refile-use-outline-path 'file)
  (setq org-outline-path-complete-in-steps nil)
  (setq org-refile-allow-creating-parent-nodes 'confirm)

  ;; ---- Tags ----
  (setq org-tag-alist '((:startgroup)
                        ("work" . ?w) ("personal" . ?p) ("learning" . ?l)
                        (:endgroup)
                        ("projectS" . ?s) ("ai" . ?a) ("hiring" . ?h)
                        ("@office" . ?o) ("@home" . ?H) ("@phone" . ?P)))

  ;; ---- Agenda views — Sean's GTD / Daily / Weekly ----
  ;; Keywords: TODO → NEXT → WAITING → DONE / CANCELLED / HOLD
  ;; Tags (mutually exclusive group): work | personal | learning
  (setq org-stuck-projects '("" nil nil ""))

  (setq org-agenda-custom-commands
        '(("g" "GTD"
           ((agenda "" ((org-agenda-span 'day)))
            (todo "NEXT"
                  ((org-agenda-overriding-header "⚡ Next Actions")
                   (org-agenda-sorting-strategy '(priority-down category-keep))))
            (todo "TODO"
                  ((org-agenda-overriding-header "📋 Tasks")
                   (org-agenda-todo-ignore-scheduled 'future)
                   (org-agenda-sorting-strategy '(tag-up priority-down category-keep))))
            (todo "WAITING"
                  ((org-agenda-overriding-header "⏳ Waiting")
                   (org-agenda-sorting-strategy '(category-keep))))
            (todo "HOLD"
                  ((org-agenda-overriding-header "🧊 On Hold")
                   (org-agenda-sorting-strategy '(category-keep))))))

          ("d" "Daily"
           ((agenda "" ((org-agenda-span 'day)
                        (org-deadline-warning-days 3)))
            (todo "NEXT"
                  ((org-agenda-overriding-header "⚡ Next Actions")
                   (org-agenda-sorting-strategy '(priority-down category-keep))))
            (todo "TODO"
                  ((org-agenda-overriding-header "📋 Tasks")
                   (org-agenda-sorting-strategy '(tag-up priority-down category-keep))))
            (todo "WAITING"
                  ((org-agenda-overriding-header "⏳ Waiting (FYI)")
                   (org-agenda-todo-ignore-scheduled 'future)
                   (org-agenda-sorting-strategy '(category-keep))))))

          ("w" "Weekly"
           ((agenda "" ((org-agenda-span 'week)
                        (org-deadline-warning-days 7)))
            (tags-todo "work"
                       ((org-agenda-overriding-header "🏢 Work")
                        (org-agenda-sorting-strategy '(todo-state-down priority-down))))
            (tags-todo "personal"
                       ((org-agenda-overriding-header "🏠 Personal")
                        (org-agenda-sorting-strategy '(todo-state-down priority-down))))
            (tags-todo "learning"
                       ((org-agenda-overriding-header "📚 Learning")
                        (org-agenda-sorting-strategy '(todo-state-down priority-down))))
            (tags-todo "-work-personal-learning"
                       ((org-agenda-overriding-header "📦 Untagged")
                        (org-agenda-sorting-strategy '(todo-state-down category-keep))))))))

  ;; ---- Babel image dir ----
  (defun my/org-babel-image-dir ()
    "Return .images/ under the current org file."
    (when buffer-file-name
      (let ((dir (expand-file-name ".images/" (file-name-directory buffer-file-name))))
        (make-directory dir t)
        dir)))

  (advice-add 'org-babel-temp-file :around
              (lambda (orig-fn prefix &optional suffix)
                (let ((dir (my/org-babel-image-dir)))
                  (if (and dir suffix (string-match-p "\\.\\(png\\|svg\\|pdf\\|jpg\\)$" suffix))
                      (let ((temporary-file-directory dir))
                        (funcall orig-fn prefix suffix))
                    (funcall orig-fn prefix suffix)))))

  ;; ---- Archive done tasks ----
  (defun my/org-archive-done-tasks ()
    "Archive all DONE or CANCELLED tasks in the current buffer.
Skip files under ~/org/collections/ to preserve records."
    (interactive)
    (let ((file (buffer-file-name)))
      (if (and file
               (string-prefix-p
                (expand-file-name "~/org/collections/")
                (expand-file-name file)))
          (message "⏭ Skipped collection file %s" (file-name-nondirectory file))
        (org-map-entries
         (lambda ()
           (org-archive-subtree)
           (setq org-map-continue-from (org-element-property :begin (org-element-at-point))))
         "/DONE|CANCELLED" 'file)
        (message "✅ Archived all done/cancelled tasks"))))
  (define-key org-mode-map (kbd "C-c A") #'my/org-archive-done-tasks))

;; Org keybindings (some already set by purcell: C-c a, C-c c, C-c l)
(global-set-key (kbd "C-c i t") 'org-toggle-inline-images)

;; ============================================================
;;  7. Org clipboard helpers
;; ============================================================

(defun my/org-download-screenshot-command ()
  "Return platform-appropriate screenshot command for org-download."
  (cond
   ((eq system-type 'windows-nt)
    "powershell -Command \"Add-Type -AssemblyName System.Windows.Forms; $img = [System.Windows.Forms.Clipboard]::GetImage(); if ($img) { $img.Save('%s', [System.Drawing.Imaging.ImageFormat]::Png) } else { Write-Error 'No image in clipboard' }\"")
   ((eq system-type 'darwin)
    "sh -c 'if command -v pngpaste >/dev/null 2>&1 && pngpaste \"$1\" >/dev/null 2>&1; then exit 0; else screencapture -i \"$1\"; fi' _ %s")
   (t
    "sh -c 'if command -v xclip >/dev/null 2>&1; then xclip -selection clipboard -t image/png -o > \"$1\" 2>/dev/null || true; fi; if [ ! -s \"$1\" ]; then if command -v wl-paste >/dev/null 2>&1; then wl-paste --no-newline --type image/png > \"$1\" 2>/dev/null || true; fi; fi; if [ ! -s \"$1\" ]; then if command -v maim >/dev/null 2>&1; then maim -s \"$1\"; elif command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1; then grim -g \"$(slurp)\" \"$1\"; fi; fi' _ %s")))

(defun my/org-paste-rich ()
  "Paste rich text (HTML with images) from clipboard as Org content."
  (interactive)
  (unless buffer-file-name
    (user-error "Please save the current buffer first"))
  (pcase system-type
    ('windows-nt
     (let* ((img-dir (expand-file-name ".images" (file-name-directory buffer-file-name)))
            (script (expand-file-name "~/org/.src/clipboard-to-org.ps1"))
            (img-dir-win (replace-regexp-in-string "/" "\\\\" img-dir))
            (script-win (replace-regexp-in-string "/" "\\\\" script))
            (cmd (format "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%s\" -ImageDir \"%s\""
                         script-win img-dir-win))
            (out-file (string-trim (shell-command-to-string cmd))))
       (if (and (not (string-blank-p out-file))
                (file-exists-p out-file))
           (progn
             (insert-file-contents out-file)
             (delete-file out-file)
             (message "✅ Rich text pasted"))
         (message "⚠ Clipboard empty or conversion failed (out: %s)" out-file))))
    ('darwin
     (let* ((script (expand-file-name "~/org/.src/clipboard-to-org-macos.sh"))
            (img-dir (expand-file-name ".images" (file-name-directory buffer-file-name))))
       (cond
        ((file-exists-p script)
         (let ((out-file (string-trim (shell-command-to-string
                                       (format "sh %s %s" (shell-quote-argument script) (shell-quote-argument img-dir))))))
           (if (and (not (string-blank-p out-file))
                    (file-exists-p out-file))
               (progn
                 (insert-file-contents out-file)
                 (delete-file out-file)
                 (message "✅ Rich text pasted"))
             (message "⚠ macOS clipboard conversion failed, falling back to plain text"))))
        ((executable-find "pbpaste")
         (let ((text (shell-command-to-string "pbpaste")))
           (if (string-blank-p text)
               (message "⚠ macOS clipboard empty; for images use org-download")
             (insert text)
             (message "✅ Plain text pasted (macOS fallback)"))))
        (t
         (message "⚠ pbpaste not found on this macOS system")))))
    (_
     (message "⚠ Rich text clipboard not implemented for this platform; use org-download"))))

(defun my/yank-markdown-as-org ()
  "Yank Markdown text from kill-ring, convert to Org via pandoc, insert at point."
  (interactive)
  (unless (executable-find "pandoc")
    (user-error "pandoc not found in PATH"))
  (save-excursion
    (with-temp-buffer
      (yank)
      (shell-command-on-region
       (point-min) (point-max)
       "pandoc -f markdown -t org --wrap=preserve"
       t t)
      (kill-region (point-min) (point-max)))
    (yank))
  (message "✅ Markdown → Org pasted"))

(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c V") #'my/org-paste-rich)
  (define-key org-mode-map (kbd "C-c M") #'my/yank-markdown-as-org))

;; ============================================================
;;  8. Org visual enhancements
;; ============================================================

;; --- org-modern (disabled) ---
;; (when (maybe-require-package 'org-modern)
;;   (add-hook 'org-mode-hook 'org-modern-mode)
;;   (add-hook 'org-agenda-finalize-hook 'org-modern-agenda)
;;   (setq org-modern-star '("◉" "○" "◈" "◇" "▣"))
;;   (setq org-modern-todo-faces
;;         '(("TODO"      :background "#0031a9" :foreground "#ffffff")
;;           ("NEXT"      :background "#d3303a" :foreground "#ffffff")
;;           ("WAITING"   :background "#884900" :foreground "#ffffff")
;;           ("HOLD"      :background "#70508f" :foreground "#ffffff")
;;           ("DONE"      :background "#006800" :foreground "#ffffff")
;;           ("CANCELLED" :background "#8f8f8f" :foreground "#ffffff")))
;;   (setq org-modern-table nil)
;;   (setq org-modern-list '((?- . "•") (?+ . "◦")))
;;   (setq org-modern-block-fringe nil))

;; --- org-appear ---
(when (maybe-require-package 'org-appear)
  (add-hook 'org-mode-hook 'org-appear-mode)
  (setq org-appear-autolinks t
        org-appear-autosubmarkers t
        org-appear-autoemphasis t
        org-appear-delay 0.3))

;; --- org-download ---
(when (maybe-require-package 'org-download)
  (add-hook 'org-mode-hook 'org-download-enable)
  (setq org-download-image-dir "./.images"
        org-download-heading-lvl nil
        org-download-timestamp "%Y%m%d%H%M%S-"
        org-download-image-org-width 800
        org-download-annotate-function (lambda (_link) "")
        org-download-screenshot-method (my/org-download-screenshot-command))
  (with-eval-after-load 'org
    (define-key org-mode-map (kbd "C-c i p") 'org-download-clipboard)
    (define-key org-mode-map (kbd "C-c i s") 'org-download-screenshot)
    (define-key org-mode-map (kbd "C-c i y") 'org-download-yank)
    (define-key org-mode-map (kbd "C-c i d") 'org-download-delete)))

;; --- iscroll (pixel-level image scrolling) ---
(when (maybe-require-package 'iscroll)
  (add-hook 'org-mode-hook 'iscroll-mode))

;; ============================================================
;;  9. Org-gcal (Google Calendar sync)
;; ============================================================

(require 'plstore)

;; Work around plstore encryption issues
(advice-add 'plstore-save :around
            (lambda (orig-fun plstore)
              (let ((secret-alist (copy-tree (plstore--get-secret-alist plstore))))
                (dolist (sec secret-alist)
                  (let ((pub (assoc (car sec) (plstore--get-alist plstore))))
                    (when pub (nconc pub (cdr sec)))))
                (plstore--set-secret-alist plstore nil)
                (unwind-protect
                    (funcall orig-fun plstore)
                  (plstore--set-secret-alist plstore secret-alist)))))

(when (maybe-require-package 'org-gcal)
  (setq org-gcal-up-days 7
        org-gcal-down-days 60)
  (global-set-key (kbd "C-c g s") 'org-gcal-sync)
  (global-set-key (kbd "C-c g f") 'org-gcal-fetch)
  (global-set-key (kbd "C-c g d") 'org-gcal-delete-at-point)

  ;; 默认推送的日历 ID
  (defvar my/org-gcal-default-calendar-id
    "f3f2ce4fb88adc5db8f25b71d3c75d20924a8c147a0feb34eafe477f173a860b@group.calendar.google.com")

  ;; 从 :org-gcal: drawer 里取出当前时间戳字符串
  (defun my/org-gcal-drawer-timestamp ()
    "返回当前 entry 的 :org-gcal: drawer 里的时间戳，没有则返回 nil。"
    (save-excursion
      (let ((end (save-excursion (outline-next-heading) (point))))
        (when (re-search-forward ":org-gcal:" end t)
          (let ((drawer-end (save-excursion
                              (re-search-forward ":END:" end t)
                              (point))))
            (let ((content (buffer-substring-no-properties (point) drawer-end)))
              (when (string-match "<[^>]+>" content)
                (match-string 0 content))))))))

  ;; 更新或新建 :org-gcal: drawer，把 timestamp 写进去
  (defun my/org-gcal-set-drawer (timestamp)
    "在当前 entry 中把 TIMESTAMP 写入 :org-gcal: drawer。"
    (save-excursion
      (let* ((entry-start (point))
             (entry-end   (save-excursion (outline-next-heading) (point))))
        (goto-char entry-start)
        (if (re-search-forward "^:org-gcal:$" entry-end t)
            ;; 已有 drawer：清空内容重写
            (let ((content-start (point)))
              (re-search-forward "^:END:$" entry-end t)
              (beginning-of-line)
              (delete-region content-start (point))
              (insert "\n" timestamp "\n"))
          ;; 没有 drawer：插在 :PROPERTIES:...:END: 之后
          (goto-char entry-start)
          (if (re-search-forward "^:END:$" entry-end t)
              (progn (end-of-line) (insert "\n:org-gcal:\n" timestamp "\n:END:"))
            ;; 连 PROPERTIES 都没有，插在 planning 行之后
            (org-end-of-meta-data nil)
            (insert ":org-gcal:\n" timestamp "\n:END:\n"))))))

  ;; 直接 PATCH GCal event 的 status 字段（org-gcal 本身不发 status）
  (defun my/org-gcal-patch-status (calendar-id event-id gcal-status)
    "向 GCal 发 PATCH，把 EVENT-ID 的 status 改为 GCAL-STATUS (\"confirmed\"/\"cancelled\")。"
    (require 'org-gcal)
    (require 'request)
    (let ((url (concat (org-gcal-events-url calendar-id)
                       "/" (url-hexify-string event-id)))
          (token (org-gcal--get-access-token calendar-id)))
      (request url
        :type "PATCH"
        :headers `(("Content-Type"  . "application/json")
                   ("Accept"        . "application/json")
                   ("Authorization" . ,(format "Bearer %s" token)))
        :data (json-encode `(("status" . ,gcal-status)))
        :parser 'org-gcal--json-read
        :success (cl-function
                  (lambda (&key _data &allow-other-keys)
                    (message "org-gcal: status → %s ✓ (%s)" gcal-status event-id)))
        :error (cl-function
                (lambda (&key error-thrown &allow-other-keys)
                  (message "org-gcal: PATCH status failed: %S" error-thrown))))))

  ;; todo state → gcal status 映射
  (defun my/org-gcal-todo-to-gcal-status (todo-state)
    "把 org todo 关键词映射到 GCal event status 字符串，无法映射返回 nil。"
    (cond
     ((member todo-state '("CANCELLED"))  "cancelled")
     ((member todo-state '("TODO" "NEXT" "WAITING" "HOLD" "DONE")) "confirmed")
     (t nil)))

  ;; 保存时自动推送：新 entry 或时间戳已修改的 entry；状态变化时额外 PATCH status
  (defun my/org-gcal-auto-post ()
    "保存 org 文件时，自动推送/更新有时间戳的 entry 到 Google Calendar。
如果 todo 状态发生变化，同时 PATCH GCal event 的 status 字段。"
    (when (derived-mode-p 'org-mode)
      (require 'org-gcal)
      (org-save-outline-visibility t
        (org-map-entries
         (lambda ()
           (let* ((scheduled   (org-entry-get nil "SCHEDULED"))
                  (deadline    (org-entry-get nil "DEADLINE"))
                  (timestamp   (or scheduled deadline))
                  (has-id      (org-entry-get nil "entry-id"))
                  (calendar-id (or (org-entry-get nil "calendar-id")
                                   my/org-gcal-default-calendar-id))
                  (todo-state  (org-get-todo-state))
                  (gcal-status (my/org-gcal-todo-to-gcal-status todo-state))
                  ;; 记录上次推送时的 todo state，用于判断是否变化
                  (last-state  (org-entry-get nil "gcal-todo-state"))
                  (state-changed (and has-id gcal-status
                                      (not (equal last-state todo-state))))
                  (drawer-ts   (my/org-gcal-drawer-timestamp))
                  (ts-changed  (and timestamp has-id
                                    (or (not drawer-ts)
                                        (not (string= (string-trim timestamp)
                                                      (string-trim drawer-ts)))))))
             ;; 1. 时间戳变化或新 entry → 走完整 post-at-point
             (when (and timestamp (or (not has-id) ts-changed))
               (my/org-gcal-set-drawer timestamp)
               (org-entry-put nil "calendar-id" calendar-id)
               (condition-case err
                   (org-gcal-post-at-point)
                 (error (message "org-gcal push failed: %s" err))))
             ;; 2. todo 状态变化 → 单独 PATCH status（post-at-point 不发 status 字段）
             (when state-changed
               (let ((event-id (org-gcal--get-id (point))))
                 (when event-id
                   (org-entry-put nil "gcal-todo-state" todo-state)
                   (my/org-gcal-patch-status calendar-id event-id gcal-status))))))
         nil 'file))))

  ;; hook 挂在外面，不依赖 org-gcal 是否已加载
  (add-hook 'after-save-hook #'my/org-gcal-auto-post)

  ;; 定时双向同步（org-gcal 加载后再启动定时器）
  (with-eval-after-load 'org-gcal
    (run-with-timer 120 1800
                    (lambda ()
                      (when (not org-gcal--sync-lock)
                        (org-gcal-sync))))))

;; ============================================================
;; 10. Org-roam (knowledge graph)
;; ============================================================

(when (maybe-require-package 'org-roam)
  (setq org-roam-directory "~/org/roam"
        org-roam-completion-everywhere t
        org-roam-capture-templates
        '(("d" "Default" plain "%?"
           :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+date: %U\n#+filetags: \n\n")
           :unnarrowed t)
          ("f" "Fleeting" plain "%?"
           :target (file+head "fleeting/%<%Y%m%d%H%M%S>-${slug}.org"
                              "#+title: ${title}\n#+date: %U\n#+filetags: :fleeting:\n\n")
           :unnarrowed t)))

  ;; ---- Web article target for org-capture ("w" template) ----
  (defun my/capture-web-article-target ()
    "Target function for org-capture: create/open a reference note from clipboard URL."
    (let* ((url (string-trim (current-kill 0 t)))
           (title (or (ignore-errors
                        (with-temp-buffer
                          (url-insert-file-contents url)
                          (goto-char (point-min))
                          (when (re-search-forward "<title>\\([^<]*\\)</title>" nil t)
                            (string-trim (match-string 1)))))
                      (read-string "Title: ")))
           (slug (replace-regexp-in-string "[^a-zA-Z0-9\u4e00-\u9fff]+" "-"
                                           (downcase (string-trim title)) t t))
           (slug (replace-regexp-in-string "^-\\|-$" "" slug))
           (file (expand-file-name (concat "references/" slug ".org") org-directory)))
      (set-buffer (org-capture-target-buffer file))
      (when (= (buffer-size) 0)
        (insert (format "#+title: %s\n#+filetags: :ref:\n#+created: %s\n\n* Source\n%s\n\n* Summary\n\n* My Notes\n"
                        title (format-time-string "[%Y-%m-%d %a]") url)))
      (goto-char (point-max))
      (or (re-search-backward "^\\* My Notes" nil t) (goto-char (point-max)))
      (forward-line 1)))

  ;; ---- org-protocol target for "pn" template ----
  ;; 与 my/capture-web-article-target 逻辑相同，
  ;; 但 URL/title 从 org-protocol plist 取（而非剪贴板）
  (defun my/protocol-note-target ()
    "Target function for org-capture 'pn': create/open a reference note.
URL and title come from org-protocol plist (%:link / %:description)."
    (let* ((url   (or (plist-get org-store-link-plist :link)
                      (plist-get org-store-link-plist :url)
                      ""))
           (title (or (plist-get org-store-link-plist :description)
                      (read-string "Title: ")))
           (slug  (replace-regexp-in-string
                   "^-\\|-$" ""
                   (replace-regexp-in-string
                    "[^a-zA-Z0-9\u4e00-\u9fff]+" "-"
                    (downcase (string-trim title)) t t)))
           (file  (expand-file-name (concat "references/" slug ".org") org-directory)))
      (set-buffer (org-capture-target-buffer file))
      (when (= (buffer-size) 0)
        (insert (format "#+title: %s\n#+filetags: :ref:\n#+created: %s\n\n* Source\n%s\n\n* Summary\n\n* My Notes\n"
                        title (format-time-string "[%Y-%m-%d %a]") url)))
      (goto-char (point-max))
      (or (re-search-backward "^\\* My Notes" nil t) (goto-char (point-max)))
      (forward-line 1)))

  (global-set-key (kbd "C-c n f") 'org-roam-node-find)
  (global-set-key (kbd "C-c n i") 'org-roam-node-insert)
  (global-set-key (kbd "C-c n l") 'org-roam-buffer-toggle)
  (global-set-key (kbd "C-c n c") 'org-roam-capture)
  (global-set-key (kbd "C-c n d") 'org-roam-dailies-goto-today)
  (global-set-key (kbd "C-c n t") 'org-roam-tag-add)
  (with-eval-after-load 'org-roam
    (make-directory (expand-file-name "roam" org-directory) t)
    (make-directory (expand-file-name "roam/fleeting" org-directory) t)
    (org-roam-db-autosync-mode)))

;; ============================================================
;; 11. Writing / reading
;; ============================================================

;; Olivetti — centered writing
;; (when (maybe-require-package 'olivetti)
;;   (add-hook 'org-mode-hook 'olivetti-mode)
;;   (add-hook 'markdown-mode-hook 'olivetti-mode)
;;   (setq olivetti-body-width 80
;;         olivetti-style 'body))  ; 'fancy 会用 fringe 背景色做侧边，light 主题下显黑

;; Enhanced markdown-mode (purcell's is minimal)
(with-eval-after-load 'markdown-mode
  (setq markdown-command "pandoc"
        markdown-fontify-code-blocks-natively t
        markdown-header-scaling t
        markdown-enable-wiki-links t
        markdown-italic-underscore t
        markdown-asymmetric-header nil
        markdown-live-preview-delete-export 'delete-on-destroy))

;; ============================================================
;; 12. Config auto-sync (arya-sync)
;; ============================================================

(defgroup arya-sync nil
  "Auto sync Emacs config repository."
  :group 'convenience)

(defcustom arya-sync-enabled t
  "Whether auto sync is enabled."
  :type 'boolean)

(defcustom arya-sync-debounce-seconds 8
  "How long to wait after save before syncing."
  :type 'number)

(defvar arya-sync--timer nil)
(defvar arya-sync--process nil)
(defvar arya-sync--buffer-name "*arya-sync*")

(defun arya-sync--repo-root ()
  (file-name-as-directory (expand-file-name user-emacs-directory)))

(defun arya-sync--buffer ()
  (get-buffer-create arya-sync--buffer-name))

(defun arya-sync--repo-file-p (file)
  (let ((tru (file-truename file))
        (root (file-truename (arya-sync--repo-root))))
    (string-prefix-p root tru)))

(defun arya-sync--sync-target-p (file)
  "Return t if FILE should trigger auto-sync."
  (when (and file (arya-sync--repo-file-p file))
    (let* ((root (arya-sync--repo-root))
           (rel (file-relative-name file root)))
      (or (member rel '("init.el" "README.md" ".gitignore" ".gitattributes" "early-init.el"))
          (string-prefix-p "lisp/" rel)
          (string-prefix-p "site-lisp/" rel)
          (string-prefix-p "scripts/" rel)))))

(defun arya-sync--script-path ()
  (expand-file-name "scripts/arya-sync-run.ps1" user-emacs-directory))

(defun arya-sync--start (mode)
  (when (and arya-sync-enabled
             (not noninteractive)
             (file-exists-p (arya-sync--script-path))
             (or (null arya-sync--process)
                 (not (process-live-p arya-sync--process))))
    (let ((buf (arya-sync--buffer))
          (mode-arg (if (eq mode 'pull) "pull" "sync")))
      (with-current-buffer buf
        (goto-char (point-max))
        (insert (format "\n[%s] arya-sync %s\n"
                        (format-time-string "%Y-%m-%d %H:%M:%S")
                        mode-arg)))
      (setq arya-sync--process
            (make-process
             :name "arya-sync"
             :buffer buf
             :command (list "pwsh" "-NoProfile" "-File" (arya-sync--script-path) mode-arg)
             :noquery t
             :sentinel
             (lambda (proc _event)
               (when (memq (process-status proc) '(exit signal))
                 (let ((code (process-exit-status proc)))
                   (message
                     (if (eq code 0)
                         (format "arya-sync: %s done" mode-arg)
                        (format "arya-sync failed (%s). See %s" code arya-sync--buffer-name)))))))))))

(defun arya-sync-pull-now ()
  "Pull latest config from git."
  (interactive)
  (arya-sync--start 'pull))

(defun arya-sync-now ()
  "Commit and push config."
  (interactive)
  (arya-sync--start 'sync))

(defun arya-sync--schedule ()
  (when arya-sync--timer
    (cancel-timer arya-sync--timer))
  (setq arya-sync--timer
        (run-with-idle-timer arya-sync-debounce-seconds nil
                             (lambda ()
                               (setq arya-sync--timer nil)
                               (arya-sync-now)))))

(defun arya-sync-after-save-hook ()
  (when (and arya-sync-enabled
             (buffer-file-name)
             (arya-sync--sync-target-p (buffer-file-name)))
    (arya-sync--schedule)))

(unless noninteractive
  (add-hook 'after-init-hook #'arya-sync-pull-now)
  (add-hook 'after-save-hook #'arya-sync-after-save-hook))

;; ============================================================
;; 13. Chinese calendar (cal-china-x)
;; ============================================================

(when (maybe-require-package 'cal-china-x)
  (with-eval-after-load 'calendar
    (require 'cal-china-x)
    (setq calendar-mark-holidays-flag t)
    (setq cal-china-x-important-holidays cal-china-x-chinese-holidays)
    (setq calendar-holidays
          (append cal-china-x-important-holidays
                  cal-china-x-general-holidays)))
  ;; 让 org-agenda 显示农历节日和 diary 里的农历生日
  (setq org-agenda-include-diary t))

;; ============================================================
;; Journal — open today's file on startup
;; ============================================================

(defun my/journal-effective-date ()
  "Return the effective date for journalling.
Before 03:00 we still consider it the previous calendar day."
  (let* ((now  (decode-time))
         (hour (nth 2 now)))
    (if (< hour 3)
        (decode-time (time-subtract (current-time) (seconds-to-time 86400)))
      now)))

(defun my/open-today-journal ()
  "Open (or create) today's journal file."
  (interactive)
  (let* ((dt   (my/journal-effective-date))
         (name (format-time-string "%Y-%m-%d.org" (encode-time dt)))
         (file (expand-file-name (concat "journal/" name) "~/org")))
    (unless (file-exists-p file)
      (with-temp-file file
        (insert (format "#+title: %s\n#+filetags: :journal:\n"
                        (format-time-string "%Y-%m-%d" (encode-time dt))))))
    (find-file file)))

;; window-setup-hook fires after desktop restore — journal always wins
;; 用 run-with-idle-timer 确保在所有 after-init 钩子（含主题、desktop等）之后执行
(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer 0.1 nil #'my/open-today-journal)))

;; ============================================================
;; Startup message
;; ============================================================

(add-hook 'after-init-hook
          (lambda ()
            (message "✓ Emacs %s (purcell + Sean) loaded!" emacs-version)))

(provide 'init-local)
;;; init-local.el ends here

;; ============================================================
;;  10. Elfeed and Elfeed-org
;; ============================================================
(when (and (maybe-require-package 'elfeed)
           (maybe-require-package 'elfeed-org))
  (require 'elfeed)
  (require 'elfeed-org)

  ;; Initialize elfeed-org
  (elfeed-org)

  ;; Specify the org file for elfeed-org
  (setq rmh-elfeed-org-files (list (expand-file-name "~/org/collections/elfeed.org")))

  ;; Default filter
  (setq-default elfeed-search-filter "@1-month-ago +unread")

  ;; Optional keybinding to start elfeed
  (global-set-key (kbd "C-c w e") 'elfeed)

  ;; Auto update when opening elfeed
  (add-hook 'elfeed-search-mode-hook #'elfeed-update)

  ;; Fix Windows MSYS2 curl limits
  (setq elfeed-curl-max-connections 4)

  ;; Use fixed-pitch (monospace) fonts for HTML rendering in Elfeed.
  ;; This prevents jagged fallback fonts and uneven spacing in Chinese.
  (add-hook 'elfeed-show-mode-hook (lambda () (setq-local shr-use-fonts nil))))


;; ============================================================
;;  11. Elfeed mpv Integration
;; ============================================================

(defun my/elfeed-play-with-mpv ()
  "Play the current elfeed entry link with mpv."
  (interactive)
  (let ((link (if (derived-mode-p 'elfeed-show-mode)
                  (elfeed-entry-link elfeed-show-entry)
                (let ((entries (elfeed-search-selected)))
                  (when entries
                    (elfeed-entry-link (car entries)))))))
    (if link
        (progn
          (message "Starting mpv for %s..." link)
          (start-process "elfeed-mpv" nil "mpv" link)
          (when (derived-mode-p 'elfeed-search-mode)
            (elfeed-search-untag-all-unread)))
      (message "No link found."))))

(with-eval-after-load 'elfeed
  (define-key elfeed-search-mode-map (kbd "v") #'my/elfeed-play-with-mpv)
  (define-key elfeed-show-mode-map (kbd "v") #'my/elfeed-play-with-mpv))


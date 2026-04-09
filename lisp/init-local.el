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

    ;; CJK fallback — use a dedicated CJK font for sharper Chinese rendering.
    ;; Maple Mono's built-in CJK glyphs are thin and look blurry at small sizes on Windows.
    (let ((cjk-font (my/first-available-font
                     '("等距更纱黑体 SC" "Sarasa Mono SC"
                       "霞鹜文楷等宽" "LXGW WenKai Mono"
                       "Microsoft YaHei UI" "Microsoft YaHei"
                       "Noto Sans SC"))))
      (when cjk-font
        (dolist (charset '(kana han cjk-misc bopomofo))
          (set-fontset-font t charset (font-spec :family cjk-font) nil 'prepend))
        ;; Keep rescale at 1.0 for comfortable CJK reading size.
        ;; Tag alignment in org-agenda handled by pixel-based hook below.
        (setq face-font-rescale-alist
              (list (cons (regexp-quote cjk-font) 1.0)))))

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

;; Theme: tsdh-light for GUI, modus-vivendi (dark) for terminal
(if (display-graphic-p)
    (setq-default custom-enabled-themes '(tsdh-light))
  (setq-default custom-enabled-themes '(modus-vivendi)))

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
  (global-set-key (kbd "M-s f") 'consult-fd)
  ;; fd: include hidden files/dirs (e.g. .calendar/)
  (setq consult-fd-args '((if (executable-find "fdfind" 'remote) "fdfind" "fd")
                           "--full-path --color=never --hidden"))

  ;; rg search in org notebook (C-c n s)
  (defun my/org-rg-search ()
    "Ripgrep search all files in `org-directory'."
    (interactive)
    (consult-ripgrep (expand-file-name org-directory)))
  (global-set-key (kbd "C-c n s") #'my/org-rg-search))

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

  ;; org-habit：在 agenda 中显示 habit 连续打卡条
  (require 'org-habit)
  (setq org-habit-graph-column 50           ; 打卡条起始列（避免挤标题）
        org-habit-preceding-days 21         ; 往前显示 21 天
        org-habit-following-days 7          ; 往后显示 7 天
        org-habit-show-habits-only-for-today nil) ; 周视图也显示 habit

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

  ;; Agenda files — 用目录路径，新 .org 文件自动纳入
  ;; 禁止 customize/C-c [ 把文件级列表写入 custom.el 覆盖此配置
  (put 'org-agenda-files 'saved-value nil)
  (put 'org-agenda-files 'customized-value nil)
  (setq org-agenda-files '("~/org/inbox.org"
                           "~/org/projects/"
                           "~/org/areas/"
                           "~/org/.calendar"
                           "~/org/journal/"))
  (setq org-default-notes-file "~/org/inbox.org")

  ;; Archive
  (setq org-archive-location
        (concat (expand-file-name ".archive/" org-directory)
                "%s_archive.org::"))

  ;; ---- Append Note helper: append to bottom, manage date separator ----
  (defun my/append-note-goto-bottom ()
    "Move point to end of append-note.org.
If today's date separator doesn't exist yet, insert it first."
    (let ((today-sep (format-time-string "-- %Y-%m-%d --")))
      (goto-char (point-max))
      (unless (save-excursion
                (goto-char (point-min))
                (search-forward today-sep nil t))
        ;; Insert today's separator at the end
        (unless (bolp) (insert "\n"))
        (insert "\n" today-sep "\n")))
    (goto-char (point-max)))

  ;; ---- Habit capture helper ----
  (defun my/org-capture-habit ()
    "Generate a capture template for a habit with selectable repeat interval."
    (let* ((name (read-string "Habit 名称: "))
           (raw  (read-string "提醒时间 (HH:MM): "))
           (repeat (completing-read "重复周期: "
                                    '(".+1d  — 每天（从完成日起）"
                                      ".+2d  — 每2天"
                                      ".+1w  — 每周"
                                      ".+2w  — 每2周"
                                      ".+1m  — 每月"
                                      "++1d  — 每天（固定日期）"
                                      "++1w  — 每周（固定星期）"
                                      ".+1d/2d — 每天，最多隔2天"
                                      ".+1d/3d — 每天，最多隔3天")
                                    nil t))
           (repeat-val (car (split-string repeat " ")))
           (parts (split-string raw ":"))
           (hour (string-to-number (nth 0 parts)))
           (min  (string-to-number (nth 1 parts)))
           (time (format "%02d:%02d" hour min))
           (today (format-time-string "%Y-%m-%d %a"))
           ;; 结束时间 = 开始 +5 分钟
           (end-min (+ min 5))
           (end-hour (+ hour (/ end-min 60)))
           (end-time (format "%02d:%02d" end-hour (% end-min 60))))
      (format "* TODO %s\nSCHEDULED: <%s %s %s>\n:PROPERTIES:\n:STYLE:    habit\n:calendar-id: yuanxiang424@gmail.com\n:END:\n:org-gcal:\n<%s %s-%s>\n:END:\n"
              name today time repeat-val today time end-time)))

  ;; ---- Capture templates ----
  (setq org-capture-templates
        '(("a" "Append Note" plain
           (file+function "~/org/append-note.org" my/append-note-goto-bottom)
           "- %?"
           :empty-lines 1 :jump-to-captured t)
          ("i" "Inbox" entry (file "~/org/inbox.org")
           "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n" :empty-lines 1)
          ("t" "Task" entry (file "~/org/inbox.org")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n" :empty-lines 1)
          ("j" "Journal" plain
           (file (lambda ()
                   (let* ((now  (decode-time))
                          (hour (nth 2 now))
                          (time (if (< hour 3)
                                    (time-subtract (current-time) (seconds-to-time 86400))
                                  (current-time))))
                     (expand-file-name
                      (format-time-string org-journal-file-format time)
                      org-journal-dir))))
           "* %(format-time-string \"%H:%M\")\n%?"
           :empty-lines 1 :jump-to-captured t)
          ("r" "r · 稍后读 [inbox]" entry (file "~/org/inbox.org")
           "* TODO [[%^{URL}][%^{Title}]]\n:PROPERTIES:\n:CREATED: %U\n:END:\n%?" :empty-lines 1)
          ("m" "Movie" entry (file+headline "~/org/collections/media.org" "观影记录")
           "* %^{片名}\n:PROPERTIES:\n:评分: %^{评分|⭐⭐⭐|⭐⭐⭐⭐|⭐⭐⭐⭐⭐|⭐⭐|⭐}\n:END:\n%U\n%?"
           :empty-lines 1)
          ("w" "w · 精读笔记 [ref/]" plain (function my/capture-web-article-target)
           "%?"
           :empty-lines 1 :jump-to-captured t)
          ("h" "Habit" entry (file "~/org/areas/habits.org")
           (function my/org-capture-habit)
           :empty-lines 1)

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

  (defun my/skip-habit ()
    "Skip entries with :STYLE: habit property."
    (let ((subtree-end (save-excursion (org-end-of-subtree t))))
      (when (string= (org-entry-get nil "STYLE") "habit")
        subtree-end)))

  (setq org-agenda-custom-commands
        '(;; ── d · Daily Focus ──────────────────────────────
          ;; 今天要干什么？最干净的每日视图
          ("d" "Daily"
           ((agenda "" ((org-agenda-span 'day)
                        (org-deadline-warning-days 3)
                        (org-agenda-skip-scheduled-if-done t)))
            (todo "NEXT"
                  ((org-agenda-overriding-header "⚡ Next Actions")
                   (org-agenda-skip-function 'my/skip-habit)
                   (org-agenda-sorting-strategy '(priority-down category-keep))))
            (todo "WAITING"
                  ((org-agenda-overriding-header "⏳ Waiting (FYI)")
                   (org-agenda-sorting-strategy '(category-keep))))))

          ;; ── w · Weekly Overview ──────────────────────────
          ;; 这周全貌，按领域分组，周初规划 / 周末回顾
          ("w" "Weekly"
           ((agenda "" ((org-agenda-span 'week)
                        (org-deadline-warning-days 7)
                        (org-habit-show-habits nil)))
            (tags-todo "+work"
                       ((org-agenda-overriding-header "🏢 Work")
                        (org-agenda-skip-function 'my/skip-habit)
                        (org-agenda-sorting-strategy '(todo-state-down priority-down))))
            (tags-todo "+personal"
                       ((org-agenda-overriding-header "🏠 Personal")
                        (org-agenda-skip-function 'my/skip-habit)
                        (org-agenda-sorting-strategy '(todo-state-down priority-down))))
            (tags-todo "+learning"
                       ((org-agenda-overriding-header "📚 Learning")
                        (org-agenda-skip-function 'my/skip-habit)
                        (org-agenda-sorting-strategy '(todo-state-down priority-down))))
            (tags-todo "-work-personal-learning"
                       ((org-agenda-overriding-header "📦 Untagged")
                        (org-agenda-skip-function 'my/skip-habit)
                        (org-agenda-sorting-strategy '(todo-state-down category-keep))))))

          ;; ── g · GTD Review ───────────────────────────────
          ;; 系统全貌，用于周回顾清理积压
          ("g" "GTD Review"
           ((agenda "" ((org-agenda-span 'day)))
            (todo "NEXT"
                  ((org-agenda-overriding-header "⚡ Next Actions")
                   (org-agenda-skip-function 'my/skip-habit)
                   (org-agenda-sorting-strategy '(priority-down category-keep))))
            (todo "TODO"
                  ((org-agenda-overriding-header "📋 All Tasks (Backlog)")
                   (org-agenda-skip-function 'my/skip-habit)
                   (org-agenda-sorting-strategy '(tag-up priority-down category-keep))))
            (todo "WAITING"
                  ((org-agenda-overriding-header "⏳ Waiting")
                   (org-agenda-sorting-strategy '(category-keep))))
            (todo "HOLD"
                  ((org-agenda-overriding-header "🧊 On Hold")
                   (org-agenda-sorting-strategy '(category-keep))))))))

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

;; --- Pixel-aligned agenda tags (fix CJK misalignment) ---
;; When CJK font is narrower than 2×ASCII, column-based alignment breaks.
;; This hook uses display properties to pixel-align tags to the right edge.
(defun my/org-agenda-align-tags-pixel ()
  "Right-align agenda tags using pixel-based display alignment.
Works correctly regardless of CJK/ASCII width ratio."
  (let ((inhibit-read-only t)
        (target-pixel (- (window-text-width nil t)
                         (* 2 (string-pixel-width " ")))))  ; 2 char right margin
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\([ \t]+\\)\\(:[[:alnum:]_@#%:]+:\\)[ \t]*$" nil t)
        (let* ((tags-str (match-string 2))
               (tags-pixel (string-pixel-width tags-str))
               (align-to (- target-pixel tags-pixel)))
          (when (> align-to 0)
            (put-text-property (match-beginning 1) (match-end 1)
                               'display `(space :align-to (,align-to)))))))))

(add-hook 'org-agenda-finalize-hook #'my/org-agenda-align-tags-pixel)

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

  ;; NOTE: 不再在 after-save-hook 自动推送 GCal。
  ;; org-gcal-post-at-point 是同步网络调用，会阻塞 Emacs。
  ;; 改为依赖：
  ;;   1. 已有的 900s 定时 org-gcal-sync（见下方 with-eval-after-load）
  ;;   2. 手动 C-c g s (org-gcal-sync) 或 C-c g p (push 当前 entry)
  ;; (add-hook 'after-save-hook #'my/org-gcal-auto-post)  ; DISABLED

  ;; 手动推送当前 entry 的快捷键
  (global-set-key (kbd "C-c g p") #'my/org-gcal-auto-post)

  ;; ── 去重：fetch 后把 gcal.org 中已在其它文件管理的 entry 删掉 ──
  (defun my/org-gcal-dedup-after-fetch ()
    "Remove entries from gcal fetch files that are already managed
in other org files (e.g. inbox.org with org-gcal-managed: org).
This prevents duplicate :entry-id: warnings."
    (let ((fetch-files (mapcar #'cdr org-gcal-fetch-file-alist))
          (known-ids (make-hash-table :test #'equal)))
      ;; 1. 收集非 fetch-file 中所有 entry-id
      (dolist (file (org-agenda-files t))
        (unless (member (expand-file-name file) (mapcar #'expand-file-name fetch-files))
          (when (file-exists-p file)
            (with-temp-buffer
              (insert-file-contents file)
              (goto-char (point-min))
              (while (re-search-forward "^[ \t]*:entry-id:[ \t]+\\(.+\\)" nil t)
                (puthash (string-trim (match-string 1)) file known-ids))))))
      ;; 2. 从每个 fetch-file 中删除重复 entry
      (dolist (fetch-file fetch-files)
        (let ((fpath (expand-file-name fetch-file)))
          (when (file-exists-p fpath)
            (with-current-buffer (find-file-noselect fpath)
              (org-with-wide-buffer
               (goto-char (point-min))
               (let ((kill-list nil))
                 (org-map-entries
                  (lambda ()
                    (let ((eid (org-entry-get nil "entry-id")))
                      (when (and eid (gethash eid known-ids))
                        (push (point) kill-list)))))
                 (when kill-list
                   ;; 从后往前删，避免位置偏移
                   (dolist (pos (sort kill-list #'>))
                     (goto-char pos)
                     (org-cut-subtree))
                   (save-buffer)
                   (message "org-gcal dedup: removed %d duplicate(s) from %s"
                            (length kill-list) fetch-file))))))))))

  (advice-add 'org-gcal-fetch :after
              (lambda (&rest _) (run-with-idle-timer 5 nil #'my/org-gcal-dedup-after-fetch)))

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
  ;; 确保 org-agenda 处理 %%() sexp 前，diary-chinese-anniversary 已定义
  ;; diary-chinese-anniversary 定义在内置 cal-china.el 中（不是 cal-china-x）
  ;; org-agenda-get-sexps 在 diary-list-entries 之前执行，
  ;; 必须提前加载 cal-china 才能让 %%() sexp 正确求值
  (with-eval-after-load 'org
    (require 'calendar)
    (require 'cal-china))
  ;; 让 org-agenda 显示农历节日和 diary 里的农历生日
  (setq org-agenda-include-diary t))

;; ============================================================
;; Journal — org-journal
;; ============================================================

(when (maybe-require-package 'org-journal)
  (setq org-journal-dir "~/org/journal/"
        org-journal-file-type 'daily
        org-journal-file-format "%Y-%m-%d.org"
        org-journal-date-format "%Y-%m-%d"
        ;; 凌晨3点前算前一天
        org-journal-start-on-weekday 1
        org-journal-carryover-items nil)

  ;; 让 org-journal 的 "j" capture 接入 org-capture
  (global-set-key (kbd "C-c j j") 'org-journal-new-entry)
  (global-set-key (kbd "C-c j t") 'org-journal-today)

  ;; 启动时自动打开今日 journal（凌晨3点前算前一天）
  (defun my/journal-open-today ()
    "Open today's journal file, creating it with proper headers if new.
Before 03:00 opens the previous day's file."
    (let* ((now  (decode-time))
           (hour (nth 2 now))
           (time (if (< hour 3)
                     (time-subtract (current-time) (seconds-to-time 86400))
                   (current-time)))
           (file (expand-file-name
                  (format-time-string org-journal-file-format time)
                  org-journal-dir))
           (new-file (not (file-exists-p file))))
      (find-file file)
      (when (and new-file (= (buffer-size) 0))
        (insert (format "#+title: %s\n#+filetags: :journal:\n"
                        (format-time-string org-journal-date-format time))))))

  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer 0.3 nil #'my/journal-open-today))))

;; ============================================================
;; Terminal Chinese Input (pyim) — emacs -nw 下 Windows IME 不工作的 workaround
;; ============================================================

;; Windows Terminal 下 emacs -nw 无法接收 IME 组合输入，
;; 用 pyim 内置拼音输入法绕过，C-\ 切换开关。
(unless (display-graphic-p)
  (when (and (maybe-require-package 'pyim)
             (maybe-require-package 'pyim-basedict))
    (require 'pyim)
    (require 'pyim-basedict)
    (pyim-basedict-enable)
    (setq default-input-method "pyim")
    ;; 全拼，单行候选框（适合终端）
    (setq pyim-default-scheme 'quanpin)
    (setq pyim-page-tooltip 'minibuffer)
    (setq pyim-page-length 5)))

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

  ;; Set Elfeed DB path to Org collections for Git syncing
  (setq elfeed-db-directory (expand-file-name "~/org/collections/.elfeed"))

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
;;  PowerShell Mode
;; ============================================================

(when (maybe-require-package 'powershell)
  (with-eval-after-load 'powershell
    ;; C-c C-c 运行整个脚本（当前文件）
    (defun my/powershell-run-file ()
      "Run the current .ps1 file with pwsh, output in compilation buffer."
      (interactive)
      (unless buffer-file-name
        (user-error "Buffer has no file"))
      (save-buffer)
      (compile (format "pwsh -NoProfile -ExecutionPolicy Bypass -File \"%s\""
                       (expand-file-name buffer-file-name))))

    ;; C-c C-r 运行选中区域（或当前行）
    (defun my/powershell-run-region ()
      "Send region (or current line) to an inferior PowerShell shell."
      (interactive)
      (let* ((beg (if (use-region-p) (region-beginning) (line-beginning-position)))
             (end (if (use-region-p) (region-end)       (line-end-position)))
             (code (buffer-substring-no-properties beg end)))
        (unless (get-buffer "*PowerShell*")
          (powershell))
        (comint-send-string (get-buffer-process "*PowerShell*")
                            (concat code "\n"))
        (display-buffer "*PowerShell*")))

    (define-key powershell-mode-map (kbd "C-c C-c") #'my/powershell-run-file)
    (define-key powershell-mode-map (kbd "C-c C-r") #'my/powershell-run-region)
    (define-key powershell-mode-map (kbd "C-c C-z") #'powershell)))

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


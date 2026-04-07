;;; init-org.el --- Org-mode config -*- lexical-binding: t -*-
;;; Commentary:

;; Among settings for many aspects of `org-mode', this code includes
;; an opinionated setup for the Getting Things Done (GTD) system based
;; around the Org Agenda.  I have an "inbox.org" file with a header
;; including

;;     #+CATEGORY: Inbox
;;     #+FILETAGS: INBOX

;; and then set this file as `org-default-notes-file'.  Captured org
;; items will then go into this file with the file-level tag, and can
;; be refiled to other locations as necessary.

;; Those other locations are generally other org files, which should
;; be added to `org-agenda-files-list' (along with "inbox.org" org).
;; With that done, there's then an agenda view, accessible via the
;; `org-agenda' command, which gives a convenient overview.
;; `org-todo-keywords' is customised here to provide corresponding
;; TODO states, which should make sense to GTD adherents.

;;; Code:

(when *is-a-mac*
  (maybe-require-package 'grab-mac-link))

(maybe-require-package 'org-cliplink)

(define-key global-map (kbd "C-c l") 'org-store-link)
(define-key global-map (kbd "C-c a") 'org-agenda)

(defvar sanityinc/org-global-prefix-map (make-sparse-keymap)
  "A keymap for handy global access to org helpers, particularly clocking.")

(define-key sanityinc/org-global-prefix-map (kbd "j") 'org-clock-goto)
(define-key sanityinc/org-global-prefix-map (kbd "l") 'org-clock-in-last)
(define-key sanityinc/org-global-prefix-map (kbd "i") 'org-clock-in)
(define-key sanityinc/org-global-prefix-map (kbd "o") 'org-clock-out)
(define-key global-map (kbd "C-c o") sanityinc/org-global-prefix-map)


;; Various preferences
(setq org-log-done t
      org-edit-timestamp-down-means-later t
      org-hide-emphasis-markers t
      org-catch-invisible-edits 'show
      org-export-coding-system 'utf-8
      org-fast-tag-selection-single-key 'expert
      org-html-validation-link nil
      org-export-kill-product-buffer-when-displayed t
      org-tags-column 80
      ;; 代码块语法高亮（org-modern 需要）
      org-src-fontify-natively t
      org-src-tab-acts-natively t
      ;; 启用缩进模式，配合 org-modern-indent 对齐块边框
      org-startup-indented t)


;; Lots of stuff from http://doc.norang.ca/org-mode.html

;; Re-align tags when window shape changes
(with-eval-after-load 'org-agenda
  (add-hook 'org-agenda-mode-hook
            (lambda () (add-hook 'window-configuration-change-hook 'org-agenda-align-tags nil t))))




(maybe-require-package 'writeroom-mode)

(define-minor-mode prose-mode
  "Set up a buffer for prose editing.
This enables or modifies a number of settings so that the
experience of editing prose is a little more like that of a
typical word processor."
  :init-value nil :lighter " Prose" :keymap nil
  (if prose-mode
      (progn
        (when (fboundp 'writeroom-mode)
          (writeroom-mode 1))
        (setq truncate-lines nil)
        (setq word-wrap t)
        (setq cursor-type 'bar)
        (when (eq major-mode 'org)
          (kill-local-variable 'buffer-face-mode-face))
        (buffer-face-mode 1)
        ;;(delete-selection-mode 1)
        (setq-local blink-cursor-interval 0.6)
        (setq-local show-trailing-whitespace nil)
        (setq-local line-spacing 0.2)
        (setq-local electric-pair-mode nil)
        (ignore-errors (flyspell-mode 1))
        (visual-line-mode 1))
    (kill-local-variable 'truncate-lines)
    (kill-local-variable 'word-wrap)
    (kill-local-variable 'cursor-type)
    (kill-local-variable 'blink-cursor-interval)
    (kill-local-variable 'show-trailing-whitespace)
    (kill-local-variable 'line-spacing)
    (kill-local-variable 'electric-pair-mode)
    (buffer-face-mode -1)
    ;; (delete-selection-mode -1)
    (flyspell-mode -1)
    (visual-line-mode -1)
    (when (fboundp 'writeroom-mode)
      (writeroom-mode 0))))

;;(add-hook 'org-mode-hook 'buffer-face-mode)


(setq org-support-shift-select t)

;;; Capturing

(global-set-key (kbd "C-c c") 'org-capture)

(setq org-capture-templates
      `(("t" "todo" entry (file "")  ; "" => `org-default-notes-file'
         "* NEXT %?\n%U\n" :clock-resume t)
        ("n" "note" entry (file "")
         "* %? :NOTE:\n%U\n%a\n" :clock-resume t)
        ))



;;; Refiling

(setq org-refile-use-cache nil)

;; Targets include this file and any file contributing to the agenda - up to 5 levels deep
(setq org-refile-targets '((nil :maxlevel . 5) (org-agenda-files :maxlevel . 5)))

(with-eval-after-load 'org-agenda
  (add-to-list 'org-agenda-after-show-hook 'org-show-entry))

(advice-add 'org-refile :after (lambda (&rest _) (org-save-all-org-buffers)))

;; Exclude DONE state tasks from refile targets
(defun sanityinc/verify-refile-target ()
  "Exclude todo keywords with a done state from refile targets."
  (not (member (nth 2 (org-heading-components)) org-done-keywords)))
(setq org-refile-target-verify-function 'sanityinc/verify-refile-target)

(defun sanityinc/org-refile-anywhere (&optional goto default-buffer rfloc msg)
  "A version of `org-refile' which allows refiling to any subtree."
  (interactive "P")
  (let ((org-refile-target-verify-function))
    (org-refile goto default-buffer rfloc msg)))

(defun sanityinc/org-agenda-refile-anywhere (&optional goto rfloc no-update)
  "A version of `org-agenda-refile' which allows refiling to any subtree."
  (interactive "P")
  (let ((org-refile-target-verify-function))
    (org-agenda-refile goto rfloc no-update)))

;; Targets start with the file name - allows creating level 1 tasks
;;(setq org-refile-use-outline-path (quote file))
(setq org-refile-use-outline-path t)
(setq org-outline-path-complete-in-steps nil)

;; Allow refile to create parent tasks with confirmation
(setq org-refile-allow-creating-parent-nodes 'confirm)


;;; To-do settings

(setq org-todo-keywords
      (quote ((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d!/!)")
              (sequence "PROJECT(p)" "|" "DONE(d!/!)" "CANCELLED(c@/!)")
              (sequence "WAITING(w@/!)" "DELEGATED(e!)" "HOLD(h)" "|" "CANCELLED(c@/!)")))
      org-todo-repeat-to-state "NEXT")

(setq org-todo-keyword-faces
      (quote (("NEXT" :inherit warning)
              ("PROJECT" :inherit font-lock-string-face))))



;;; Agenda views

(setq-default org-agenda-clockreport-parameter-plist '(:link t :maxlevel 3))


(setq org-stuck-projects
      '("-INBOX/PROJECT" ("NEXT")))

(let ((active-project-match '(car org-stuck-projects)))

  (setq org-agenda-skip-additional-timestamps-in-entry t
        org-agenda-skip-deadline-prewarning-if-scheduled t
        org-agenda-compact-blocks t
        org-agenda-sticky t
        org-agenda-start-on-weekday nil
        org-agenda-span 'day
        org-agenda-include-diary nil
        org-agenda-sorting-strategy
        '((agenda habit-down time-up user-defined-up effort-up category-keep)
          (todo category-up effort-up)
          (tags category-up effort-up)
          (search category-up))
        org-agenda-window-setup 'current-window
        org-agenda-prefix-format
        '((agenda . " %i %-12:c%?-12t% s")
          (todo   . " %i %-12:c%s")
          (tags   . " %i %-12:c%s")
          (search . " %i %-12:c"))
        org-agenda-time-grid
        '((daily require-timed)
          (800 900 1000 1100 1200 1300 1400 1500 1600 1700 1800 1900 2000)
          "......"
          "----------------")
        org-agenda-custom-commands
        `(("N" "Notes" tags "NOTE"
           ((org-agenda-overriding-header "Notes")
            (org-tags-match-list-sublevels t)))
          ("g" "GTD"
           ((agenda "" nil)
            (tags "INBOX"
                  ((org-agenda-overriding-header "Inbox")
                   (org-tags-match-list-sublevels nil)))
            (stuck ""
                   ((org-agenda-overriding-header "Stuck Projects")
                    (org-agenda-tags-todo-honor-ignore-options t)
                    (org-tags-match-list-sublevels t)
                    (org-agenda-todo-ignore-scheduled 'future)))
             (tags-todo "-INBOX"
                        ((org-agenda-overriding-header "Next Actions")
                         (org-agenda-tags-todo-honor-ignore-options t)
                         (org-agenda-todo-ignore-scheduled 'future)
                         (org-agenda-skip-function
                          '(lambda ()
                             (or (org-agenda-skip-subtree-if 'todo '("HOLD" "WAITING"))
                                 (org-agenda-skip-entry-if 'nottodo '("NEXT")))))
                         (org-tags-match-list-sublevels t)
                         (org-agenda-prefix-format " %-12:c %(let ((s (org-entry-get nil \"SCHEDULED\"))) (if s (concat \"[\" (format-time-string \"%m-%d %H:%M\" (org-time-string-to-time s)) \"] \") \"          \"))")
                         (org-agenda-sorting-strategy
                          '(todo-state-down effort-up category-keep))))
            (tags-todo ,active-project-match
                       ((org-agenda-overriding-header "Projects")
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-INBOX/-NEXT"
                       ((org-agenda-overriding-header "Orphaned Tasks")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("PROJECT" "HOLD" "WAITING" "DELEGATED"))
                                (org-agenda-skip-subtree-if 'nottododo '("TODO")))))
                        (org-tags-match-list-sublevels t)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "/WAITING"
                       ((org-agenda-overriding-header "Waiting")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "/DELEGATED"
                       ((org-agenda-overriding-header "Delegated")
                        (org-agenda-tags-todo-honor-ignore-options t)
                        (org-agenda-todo-ignore-scheduled 'future)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            (tags-todo "-INBOX"
                       ((org-agenda-overriding-header "On Hold")
                        (org-agenda-skip-function
                         '(lambda ()
                            (or (org-agenda-skip-subtree-if 'todo '("WAITING"))
                                (org-agenda-skip-entry-if 'nottodo '("HOLD")))))
                        (org-tags-match-list-sublevels nil)
                        (org-agenda-sorting-strategy
                         '(category-keep))))
            ;; (tags-todo "-NEXT"
            ;;            ((org-agenda-overriding-header "All other TODOs")
            ;;             (org-match-list-sublevels t)))
            )))))


(add-hook 'org-agenda-mode-hook 'hl-line-mode)


;;; Org clock

;; Save the running clock and all clock history when exiting Emacs, load it on startup
(with-eval-after-load 'org
  (org-clock-persistence-insinuate))
(setq org-clock-persist t)
(setq org-clock-in-resume t)

;; Save clock data and notes in the LOGBOOK drawer
(setq org-clock-into-drawer t)
;; Save state changes in the LOGBOOK drawer
(setq org-log-into-drawer t)
;; Removes clocked tasks with 0:00 duration
(setq org-clock-out-remove-zero-time-clocks t)

;; Show clock sums as hours and minutes, not "n days" etc.
(setq org-time-clocksum-format
      '(:hours "%d" :require-hours t :minutes ":%02d" :require-minutes t))



;;; Show the clocked-in task - if any - in the header line
(defun sanityinc/show-org-clock-in-header-line ()
  (setq-default header-line-format '((" " org-mode-line-string " "))))

(defun sanityinc/hide-org-clock-from-header-line ()
  (setq-default header-line-format nil))

(add-hook 'org-clock-in-hook 'sanityinc/show-org-clock-in-header-line)
(add-hook 'org-clock-out-hook 'sanityinc/hide-org-clock-from-header-line)
(add-hook 'org-clock-cancel-hook 'sanityinc/hide-org-clock-from-header-line)

(with-eval-after-load 'org-clock
  (define-key org-clock-mode-line-map [header-line mouse-2] 'org-clock-goto)
  (define-key org-clock-mode-line-map [header-line mouse-1] 'org-clock-menu))



(when (and *is-a-mac* (file-directory-p "/Applications/org-clock-statusbar.app"))
  (add-hook 'org-clock-in-hook
            (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                (concat "tell application \"org-clock-statusbar\" to clock in \"" org-clock-current-task "\""))))
  (add-hook 'org-clock-out-hook
            (lambda () (call-process "/usr/bin/osascript" nil 0 nil "-e"
                                "tell application \"org-clock-statusbar\" to clock out"))))



;; TODO: warn about inconsistent items, e.g. TODO inside non-PROJECT
;; TODO: nested projects!



;;; Archiving

(setq org-archive-mark-done nil)
(setq org-archive-location "%s_archive::* Archive")





(require-package 'org-pomodoro)
(setq org-pomodoro-keep-killed-pomodoro-time t)
(with-eval-after-load 'org-agenda
  (define-key org-agenda-mode-map (kbd "P") 'org-pomodoro))


;;; org-appear: show emphasis markers when cursor is inside them
;; already installed in elpa-30.2, just needs to be enabled
(when (maybe-require-package 'org-appear)
  (add-hook 'org-mode-hook 'org-appear-mode)
  (setq org-appear-autolinks t
        org-appear-autosubmarkers t
        org-appear-autoentities t))


;;; org-autolist: smart list continuation in org-mode
;; The package uses defadvice which doesn't work reliably in Emacs 30.
;; We load it for the minor mode definition, but replace the two broken
;; advices with modern advice-add equivalents.
(when (maybe-require-package 'org-autolist)
  ;; Patch: re-implement the two defadvice hooks using advice-add
  (with-eval-after-load 'org-autolist
    ;; Remove the broken defadvice-based activations from the minor mode
    (advice-add 'org-autolist-mode :after
                (lambda (&rest _)
                  ;; org-return replacement
                  (if org-autolist-mode
                      (progn
                        (advice-add 'org-return :around #'sanityinc/org-autolist-return)
                        (advice-add 'org-delete-backward-char :around #'sanityinc/org-autolist-delete-backward-char))
                    (advice-remove 'org-return #'sanityinc/org-autolist-return)
                    (advice-remove 'org-delete-backward-char #'sanityinc/org-autolist-delete-backward-char)))))

  (with-eval-after-load 'org
    (defun sanityinc/org-autolist-return (orig-fn &rest args)
      "advice-add replacement for org-autolist's org-return advice."
      (let* ((el (org-element-at-point))
             (parent (plist-get (cadr el) :parent))
             (is-listitem (or (org-at-item-p)
                              (and (eq 'paragraph (car el))
                                   (eq 'item (car parent)))))
             (is-checkbox (plist-get (cadr parent) :checkbox)))
        (if (and is-listitem
                 (not (and org-return-follows-link
                           (eq 'org-link (get-text-property (point) 'face)))))
            (if (and (eolp)
                     (org-at-item-p)
                     (<= (point) (org-autolist-beginning-of-item-after-bullet)))
                (condition-case nil
                    (call-interactively 'org-outdent-item)
                  (error (delete-region (line-beginning-position)
                                        (line-end-position))))
              (cond
               (is-checkbox (org-insert-todo-heading nil))
               ((and (org-at-item-description-p)
                     (> (point) (org-autolist-beginning-of-item-after-bullet))
                     (< (point) (line-end-position)))
                (newline))
               (t (org-meta-return))))
          (apply orig-fn args))))

    (defun sanityinc/org-autolist-delete-backward-char (orig-fn &rest args)
      "advice-add replacement for org-autolist's org-delete-backward-char advice."
      (if (and org-autolist-enable-delete
               (org-at-item-p)
               (<= (point) (org-autolist-beginning-of-item-after-bullet)))
          (if (org-previous-line-empty-p)
              (delete-region (line-beginning-position)
                             (save-excursion (forward-line -1)
                                             (line-beginning-position)))
            (progn
              (goto-char (org-autolist-beginning-of-item-after-bullet))
              (cond
               ((= 1 (line-number-at-pos))
                (delete-region (point) (line-beginning-position)))
               ((org-autolist-at-empty-item-description-p)
                (delete-region (line-end-position)
                               (save-excursion (forward-line -1)
                                               (line-end-position))))
               (t
                (delete-region (point)
                               (save-excursion (forward-line -1)
                                               (line-end-position)))))))
        (apply orig-fn args))))

  (add-hook 'org-mode-hook 'org-autolist-mode))


;;; org-modern: modern styling for org-mode (headings, blocks, tables, etc.)
(when (maybe-require-package 'org-modern)
  ;; 确保在 org-modern 渲染前设定全局默认值
  (setq-default
   ;; 1. 标题符号：箭头 + 菱形
   ;; 适配最新版 org-modern API
   org-modern-star 'replace
   org-modern-replace-stars '("▶" "▷" "◆" "◇" "◈")
   org-modern-hide-stars nil  ; 开启 org-indent 时设为 nil 避免冲突
   org-modern-list '((45 . "•") (43 . "◦") (42 . "▪"))

   ;; 2. TODO 关键词胶囊配色（浅色主题适用：柔和背景 + 深色文字）
   org-modern-todo t
   org-modern-todo-faces
   '(("TODO"      :background "#dbeafe" :foreground "#0369a1" :weight bold)  ; 浅蓝底 深蓝字
     ("NEXT"      :background "#fee2e2" :foreground "#b91c1c" :weight bold)  ; 浅红底 深红字
     ("WAITING"   :background "#fef08a" :foreground "#a16207" :weight bold)  ; 浅黄底 深黄字
     ("HOLD"      :background "#e5e7eb" :foreground "#4b5563" :weight bold)  ; 浅灰底 中灰字
     ("DONE"      :background "#dcfce7" :foreground "#15803d" :weight bold)  ; 浅绿底 深绿字
     ("CANCELLED" :background "#f3f4f6" :foreground "#9ca3af" :weight bold)) ; 极浅灰 浅灰字

   ;; 3. 优先级胶囊配色（浅色主题适用：柔和色系）
   org-modern-priority t
   org-modern-priority-faces
   '((?A :background "#fee2e2" :foreground "#b91c1c" :weight bold)
     (?B :background "#ffedd5" :foreground "#c2410c" :weight bold)
     (?C :background "#dcfce7" :foreground "#15803d" :weight bold))

   ;; 4. 代码块标头：加 ▶ / ◀ 前缀
   org-modern-block-name
   '(("src"     . ("▶ " " ◀"))
     ("example" . ("▶ " " ◀"))
     ("quote"   . ("❝ " " ❞"))
     ("verse"   . ("❝ " " ❞"))
     ("comment" . ("# " "  ")))

   ;; 6. 标签胶囊样式（浅色主题适用：柔和背景 + 深色文字）
   org-modern-tag t
   org-modern-tag-faces
   '(("work"     :background "#e0f2fe" :foreground "#0369a1" :weight bold)
     ("personal" :background "#dcfce7" :foreground "#15803d" :weight bold)
     ("learning" :background "#fef08a" :foreground "#b45309" :weight bold)
     ("Project_S" :background "#f3e8ff" :foreground "#7e22ce" :weight bold)  ; 浅紫底 紫字
     ("emacs"    :background "#ffedd5" :foreground "#c2410c" :weight bold)  ; 浅橙底 橙字
     ("AI"       :background "#ecfeff" :foreground "#0f766e" :weight bold)) ; 浅青底 青字

   ;; 7. 表格美化
   org-modern-table t

   ;; 其余保持不变
   org-modern-keyword t
   org-modern-checkbox '((?X . "☑") (?- . "◐") (?\s . "☐"))
   org-modern-block-fringe nil)

  ;; 调整 block 名称字体颜色，避免在浅色背景下看不清
  (custom-set-faces
   '(org-modern-block-name ((t (:foreground "#4b5563" :background "#f3f4f6" :weight bold)))))

  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda))

;;; org-modern-indent: fix bullet alignment when org-indent-mode + org-modern are both active
;; Not on MELPA; install from GitHub via package-vc (Emacs 29+)
(when (fboundp 'package-vc-install)
  (unless (package-installed-p 'org-modern-indent)
    (package-vc-install "https://github.com/jdtsmith/org-modern-indent"))
  (with-eval-after-load 'org-modern
    (add-hook 'org-modern-mode-hook #'org-modern-indent-mode)))


;; ;; Show iCal calendars in the org agenda
;; (when (and *is-a-mac* (require 'org-mac-iCal nil t))
;;   (setq org-agenda-include-diary t
;;         org-agenda-custom-commands
;;         '(("I" "Import diary from iCal" agenda ""
;;            ((org-agenda-mode-hook #'org-mac-iCal)))))

;;   (add-hook 'org-agenda-cleanup-fancy-diary-hook
;;             (lambda ()
;;               (goto-char (point-min))
;;               (save-excursion
;;                 (while (re-search-forward "^[a-z]" nil t)
;;                   (goto-char (match-beginning 0))
;;                   (insert "0:00-24:00 ")))
;;               (while (re-search-forward "^ [a-z]" nil t)
;;                 (goto-char (match-beginning 0))
;;                 (save-excursion
;;                   (re-search-backward "^[0-9]+:[0-9]+-[0-9]+:[0-9]+ " nil t))
;;                 (insert (match-string 0))))))


(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-M-<up>") 'org-up-element)
  (when *is-a-mac*
    (define-key org-mode-map (kbd "M-h") nil)
    (define-key org-mode-map (kbd "C-c g") 'grab-mac-link)))

(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   (seq-filter
    (lambda (pair)
      (locate-library (concat "ob-" (symbol-name (car pair)))))
    '((R . t)
      (ditaa . t)
      (dot . t)
      (emacs-lisp . t)
      (gnuplot . t)
      (haskell . nil)
      (latex . t)
      (ledger . t)
      (ocaml . nil)
      (octave . t)
      (plantuml . t)
      (python . t)
      (ruby . t)
      (screen . nil)
      (sh . t) ;; obsolete
      (shell . t)
      (sql . t)
      (sqlite . t)))))


;;; org-journal

(when (maybe-require-package 'org-journal)
  (setq org-journal-dir "~/org/journal/"
        ;; 每天一个文件，文件名格式与现有文件一致：2026-04-07.org
        org-journal-file-type 'daily
        org-journal-file-format "%Y-%m-%d.org"
        ;; 条目 heading 只用时间，不加额外前缀
        org-journal-date-format "%Y-%m-%d"
        org-journal-time-format "%H:%M"
        ;; 文件头与现有格式一致
        org-journal-file-header "#+title: %Y-%m-%d\n#+filetags: :journal:\n"
        ;; 加入 org-agenda
        org-journal-enable-agenda-integration t)

  ;; journal 目录下的文件自动激活 org-journal-mode
  (add-to-list 'auto-mode-alist
               `(,(concat (regexp-quote (expand-file-name org-journal-dir)) ".*\\.org\\'")
                 . org-journal-mode))

  ;; 快捷键：C-c j j 打开今天，C-c j y 打开昨天，C-c j s 搜索
  (with-eval-after-load 'org-journal
    (define-key global-map (kbd "C-c j j") 'org-journal-new-entry)
    (define-key global-map (kbd "C-c j y")
      (lambda () (interactive)
        (org-journal-new-entry nil (time-subtract (current-time) (days-to-time 1)))))
    (define-key global-map (kbd "C-c j s") 'org-journal-search)))

(provide 'init-org)
;;; init-org.el ends here

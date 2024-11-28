;;; org-block-icons.el --- Replace org src block headers with icons -*- lexical-binding: t -*-

;; Copyright (C) 2024 Free Software Foundation, Inc.

;; Author: Laluxx
;; Version: 0.1.0
;fff; Package-Requires: ((emacs "27.1") (nerd-icons "0.1.0"))
;; Keywords: convenience, org, look,
;; URL: https://github.com/laluxx/org-block-icons

;;; Commentary:

;; This package replaces Org mode source block delimiters with programming
;; language icons from nerd-icons.  It provides a cleaner look while
;; maintaining the block's language identification through visual icons.

;; It also support block inseretion with hydra

;;; Code:

(require 'org)
(require 'nerd-icons)
(require 'hydra)

(defvar org-block-icons-common-languages
  '(("e" "elisp")
    ("p" "python")
    ("j" "javascript")
    ("s" "shell")
    ("r" "rust")
    ("c" "c++")
    ("h" "haskell")
    ("l" "latex")
    ("x" "xml")
    ("y" "yaml"))
  "List of common languages for source blocks.")

(defun org-block-icons--insert-src-block (lang)
  "Insert a source block for the given LANG."
  (insert (format "#+begin_src %s\n\n#+end_src" lang))
  (forward-line -1))

(defun org-block-icons--insert-custom-src-block ()
  "Insert a source block with custom language."
  (interactive)
  (let ((lang (read-string "Language: ")))
    (org-block-icons--insert-src-block lang)))

(defhydra org-block-icons-hydra (:color blue :hint nil)
  "
^Source Blocks^
_e_: Elisp       _j_: JavaScript   _c_: C++
_p_: Python      _s_: Shell        _h_: Haskell
_r_: Rust        _l_: LaTeX        _x_: XML
                 _y_: YAML

^Special Blocks^
_q_: Quote       _E_: Example      _v_: Verse
_t_: Center      _C_: Comment      _n_: Notes

^Other^
_RET_: Plain Block
_i_: Insert Custom Lang
_b_: Back to Buffer
"
  ("e" (lambda () (interactive) (org-block-icons--insert-src-block "elisp")))
  ("p" (lambda () (interactive) (org-block-icons--insert-src-block "python")))
  ("j" (lambda () (interactive) (org-block-icons--insert-src-block "javascript")))
  ("s" (lambda () (interactive) (org-block-icons--insert-src-block "shell")))
  ("r" (lambda () (interactive) (org-block-icons--insert-src-block "rust")))
  ("c" (lambda () (interactive) (org-block-icons--insert-src-block "c++")))
  ("h" (lambda () (interactive) (org-block-icons--insert-src-block "haskell")))
  ("l" (lambda () (interactive) (org-block-icons--insert-src-block "latex")))
  ("x" (lambda () (interactive) (org-block-icons--insert-src-block "xml")))
  ("y" (lambda () (interactive) (org-block-icons--insert-src-block "yaml")))
  
  ;; Special blocks
  ("q" (lambda () (interactive) 
         (insert "#+begin_quote\n\n#+end_quote") 
         (forward-line -1)))
  ("E" (lambda () (interactive) 
         (insert "#+begin_example\n\n#+end_example") 
         (forward-line -1)))
  ("v" (lambda () (interactive) 
         (insert "#+begin_verse\n\n#+end_verse") 
         (forward-line -1)))
  ("t" (lambda () (interactive) 
         (insert "#+begin_center\n\n#+end_center") 
         (forward-line -1)))
  ("C" (lambda () (interactive) 
         (insert "#+begin_comment\n\n#+end_comment") 
         (forward-line -1)))
  ("n" (lambda () (interactive) 
         (insert "#+begin_notes\n\n#+end_notes") 
         (forward-line -1)))
  
  ("RET" (lambda () (interactive) 
           (insert "#+begin_\n\n#+end_") 
           (forward-line -1)))
  ("i" org-block-icons--insert-custom-src-block)
  ("b" nil "back"))

;; Define the mode map
(defvar org-block-icons-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-j") #'org-block-icons-hydra/body)
    map)
  "Keymap for `org-block-icons-mode'.")

;;;###autoload
(define-minor-mode org-block-icons-mode
  "Replace org source block delimiters with icons."
  :lighter " OrgIcons"
  :keymap org-block-icons-mode-map
  (if org-block-icons-mode
      (progn
        ;; Initial update
        (org-block-icons--update)
        ;; Setup hooks for dynamic updates
        (add-hook 'after-change-functions #'org-block-icons--update nil t)
        ;; Update when window scrolls or changes
        (add-hook 'window-scroll-functions
                  (lambda (&rest _) (org-block-icons--update))
                  nil t))
    ;; Cleanup when disabled
    (org-block-icons--clear-overlays)
    (remove-hook 'after-change-functions #'org-block-icons--update t)
    (remove-hook 'window-scroll-functions #'org-block-icons--update t)))

(defgroup org-block-icons nil
  "Customization group for org-block-icons."
  :group 'org
  :prefix "org-block-icons-")

(defcustom org-block-icons-padding-right "  "
  "Padding to add after the icon."
  :type 'string
  :group 'org-block-icons)

(defvar-local org-block-icons--overlays nil
  "List to store block icon overlays for cleanup.")

(defun org-block-icons--get-mode (lang)
  "Convert org src block LANG to its major mode."
  (intern (format "%s-mode"
                  (pcase lang
                    ("elisp" "emacs-lisp")
                    ("sh" "shell")
                    (other other)))))

(defun org-block-icons--create-icon-overlay (beg end lang)
  "Create overlay for src block between BEG and END with LANG icon."
  (let* ((mode (org-block-icons--get-mode lang))
         (icon (concat
                (nerd-icons-icon-for-mode mode)
                org-block-icons-padding-right))
         (ov (make-overlay beg end)))
    ;; Store overlay for cleanup
    (push ov org-block-icons--overlays)
    ;; Make the begin_src line invisible
    (overlay-put ov 'invisible t)
    ;; Add icon at the exact position where content starts
    (overlay-put ov 'after-string 
                 (propertize " " 'display icon))))

(defun org-block-icons--create-end-overlay (beg end)
  "Create overlay to hide end_src line between BEG and END."
  (let ((ov (make-overlay beg end)))
    (push ov org-block-icons--overlays)
    (overlay-put ov 'invisible t)))

(defun org-block-icons--update (&rest _)
  "Update icons in the visible portion of the buffer."
  (when org-block-icons-mode
    (save-excursion
      (goto-char (point-min))
      ;; Clear existing overlays
      (org-block-icons--clear-overlays)
      ;; Recreate overlays
      (while (re-search-forward "^[ \t]*#\\+begin_src\\s-+\\([^ \t\n]+\\)" nil t)
        (let* ((lang (match-string 1))
               (block-beg (line-beginning-position))
               (block-end (line-end-position)))
          ;; Create overlay for begin_src line with icon
          (org-block-icons--create-icon-overlay block-beg block-end lang)
          ;; Find and hide the matching end_src line
          (when (re-search-forward "^[ \t]*#\\+end_src" nil t)
            (org-block-icons--create-end-overlay 
             (line-beginning-position)
             (line-end-position))))))))

(defun org-block-icons--clear-overlays ()
  "Clear all block icon overlays."
  (mapc #'delete-overlay org-block-icons--overlays)
  (setq org-block-icons--overlays nil))

;;;###autoload
(define-minor-mode org-block-icons-mode
  "Replace org source block delimiters with icons."
  :lighter " OrgIcons"
  (if org-block-icons-mode
      (progn
        ;; Initial update
        (org-block-icons--update)
        ;; Setup hooks for dynamic updates
        (add-hook 'after-change-functions #'org-block-icons--update nil t)
        ;; Update when window scrolls or changes
        (add-hook 'window-scroll-functions
                  (lambda (&rest _) (org-block-icons--update))
                  nil t))
    ;; Cleanup when disabled
    (org-block-icons--clear-overlays)
    (remove-hook 'after-change-functions #'org-block-icons--update t)
    (remove-hook 'window-scroll-functions #'org-block-icons--update t)))

;;;###autoload
(defun org-block-icons-enable ()
  "Enable org-block-icons for the current buffer."
  (org-block-icons-mode 1))

;;;###autoload
(define-globalized-minor-mode
  global-org-block-icons-mode
  org-block-icons-mode
  (lambda ()
    (when (derived-mode-p 'org-mode)
      (org-block-icons-enable))))

(provide 'org-block-icons)

;;; org-block-icons.el ends here

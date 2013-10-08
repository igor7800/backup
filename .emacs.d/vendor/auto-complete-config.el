;;; auto-complete-config.el --- auto-complete additional configuations

;; Copyright (C) 2009, 2010  Tomohiro Matsuyama

;; Author: Tomohiro Matsuyama <m2ym.pub@gmail.com>
;; Keywords: convenience
;; Version: 1.3.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:



;;; Code:

(eval-when-compile
  (require 'cl))

;; Utilities

(defvar popup-use-optimized-column-computation t
  "Use optimized column computation routine.
If there is a problem, please set it to nil.")

;; Borrowed from anything.el
(defmacro popup-aif (test-form then-form &rest else-forms)
  "Anaphoric if. Temporary variable `it' is the result of test-form."
  (declare (indent 2))
  `(let ((it ,test-form))
     (if it ,then-form ,@else-forms)))

(defun popup-x-to-string (x)
  "Convert any object to string effeciently.
This is faster than prin1-to-string in many cases."
  (typecase x
    (string x)
    (symbol (symbol-name x))
    (integer (number-to-string x))
    (float (number-to-string x))
    (t (format "%s" x))))

(defun popup-substring-by-width (string width)
  "Return cons of substring and remaining string by `WIDTH'."
  ;; Expand tabs with 4 spaces
  (setq string (replace-regexp-in-string "\t" "    " string))
  (loop with len = (length string)
        with w = 0
        for l from 0
        for c in (append string nil)
        while (<= (incf w (char-width c)) width)
        finally return
        (if (< l len)
            (cons (substring string 0 l) (substring string l))
          (list string))))

(defun popup-fill-string (string &optional width max-width justify squeeze)
  "Split STRING into fixed width strings and return a cons cell like
\(WIDTH . ROWS). Here, the car WIDTH indicates the actual maxim width of ROWS.

The argument WIDTH specifies the width of filling each paragraph. WIDTH nil
means don't perform any justification and word wrap. Note that this function
doesn't add any padding characters at the end of each row.

MAX-WIDTH, if WIDTH is nil, specifies the maximum number of columns.

The optional fourth argument JUSTIFY specifies which kind of justification
to do: `full', `left', `right', `center', or `none' (equivalent to nil).
A value of t means handle each paragraph as specified by its text properties.

SQUEEZE nil means leave whitespaces other than line breaks untouched."
  (if (eq width 0)
      (error "Can't fill string with 0 width"))
  (if width
      (setq max-width width))
  (with-temp-buffer
    (let ((tab-width 4)
          (fill-column width)
          (left-margin 0)
          (kinsoku-limit 1)
          indent-tabs-mode
          row rows)
      (insert string)
      (untabify (point-min) (point-max))
      (if width
          (fill-region (point-min) (point-max) justify (not squeeze)))
      (goto-char (point-min))
      (setq width 0)
      (while (prog2
                 (let ((line (buffer-substring
                              (point) (progn (end-of-line) (point)))))
                   (if max-width
                       (while (progn
                                (setq row (truncate-string-to-width line max-width)
                                      width (max width (string-width row)))
                                (push row rows)
                                (if (not (= (length row) (length line)))
                                    (setq line (substring line (length row))))))
                     (setq width (max width (string-width line)))
                     (push line rows)))
                 (< (point) (point-max))
               (beginning-of-line 2)))
      (cons width (nreverse rows)))))

(defmacro popup-save-buffer-state (&rest body)
  (declare (indent 0))
  `(save-excursion
     (let ((buffer-undo-list t)
           (buffer-read-only nil)
           (modified (buffer-modified-p)))
       (unwind-protect
           (progn ,@body)
         (set-buffer-modified-p modified)))))
  
(defun popup-preferred-width (list)
  "Return preferred width of popup to show `LIST' beautifully."
  (loop with tab-width = 4
        for item in list
        for summary = (popup-item-summary item)
        maximize (string-width (popup-x-to-string item)) into width
        if (stringp summary)
        maximize (+ (string-width summary) 2) into summary-width
        finally return (* (ceiling (/ (+ (or width 0) (or summary-width 0)) 10.0)) 10)))

;; window-full-width-p is not defined in Emacs 22.1
(defun popup-window-full-width-p (&optional window)
  (if (fboundp 'window-full-width-p)
      (window-full-width-p window)
    (= (window-width window) (frame-width (window-frame (or window (selected-window)))))))

;; truncated-partial-width-window-p is not defined in Emacs 22
(defun popup-truncated-partial-width-window-p (&optional window)
  (unless window
    (setq window (selected-window)))
  (unless (popup-window-full-width-p window)
    (let ((t-p-w-w (buffer-local-value 'truncate-partial-width-windows
				       (window-buffer window))))
      (if (integerp t-p-w-w)
	  (< (window-width window) t-p-w-w)
	t-p-w-w))))

(defun popup-current-physical-column ()
  (or (when (and popup-use-optimized-column-computation
                 (eq (window-hscroll) 0))
        (let ((current-column (current-column)))
          (if (or (popup-truncated-partial-width-window-p)
                  truncate-lines
                  (< current-column (window-width)))
              current-column)))
      (car (posn-col-row (posn-at-point)))))

(defun popup-last-line-of-buffer-p ()
  (save-excursion (end-of-line) (/= (forward-line) 0)))

(defun popup-lookup-key-by-event (function event)
  (or (funcall function (vector event))
      (if (symbolp event)
          (popup-aif (get event 'event-symbol-element-mask)
              (funcall function (vector (logior (or (get (car it) 'ascii-character) 0)
                                                (cadr it))))))))



;; Popup common

(defgroup popup nil
  "Visual popup interface"
  :group 'lisp
  :prefix "popup-")

(defface popup-face
  '((t (:background "lightgray" :foreground "black")))
  "Face for popup."
  :group 'popup)

(defface popup-scroll-bar-foreground-face
  '((t (:background "black")))
  "Foreground face for scroll-bar."
  :group 'popup)

(defface popup-scroll-bar-background-face
  '((t (:background "gray")))
  "Background face for scroll-bar."
  :group 'popup)

(defvar popup-instances nil
  "Popup instances.")

(defvar popup-scroll-bar-foreground-char
  (propertize " " 'face 'popup-scroll-bar-foreground-face)
  "Foreground character for scroll-bar.")

(defvar popup-scroll-bar-background-char
  (propertize " " 'face 'popup-scroll-bar-background-face)
  "Background character for scroll-bar.")

(defstruct popup
  point row column width height min-height direction overlays
  parent depth
  face selection-face
  margin-left margin-right margin-left-cancel scroll-bar symbol
  cursor offset scroll-top current-height list newlines
  pattern original-list)

(defun popup-item-propertize (item &rest properties)
  "Same to `propertize` but this avoids overriding existed value with `nil` property."
  (let (props)
    (while properties
      (when (cadr properties)
        (push (car properties) props)
        (push (cadr properties) props))
      (setq properties (cddr properties)))
    (apply 'propertize
           (popup-x-to-string item)
           (nreverse props))))

(defun popup-item-property (item property)
  (if (stringp item)
      (get-text-property 0 property item)))

(defun* popup-make-item (name
                         &key
                         value
                         popup-face
                         selection-face
                         sublist
                         document
                         symbol
                         summary)
  "Utility function to make popup item.
See also `popup-item-propertize'."
  (popup-item-propertize name
                         'value value
                         'popup-face popup-face
                         'selection-face selection-face
                         'document document
                         'symbol symbol
                         'summary summary
                         'sublist sublist))

(defsubst popup-item-value (item)               (popup-item-property item 'value))
(defsubst popup-item-value-or-self (item)       (or (popup-item-value item) item))
(defsubst popup-item-popup-face (item)          (popup-item-property item 'popup-face))
(defsubst popup-item-selection-face (item)      (popup-item-property item 'selection-face))
(defsubst popup-item-document (item)            (popup-item-property item 'document))
(defsubst popup-item-summary (item)             (popup-item-property item 'summary))
(defsubst popup-item-symbol (item)              (popup-item-property item 'symbol))
(defsubst popup-item-sublist (item)             (popup-item-property item 'sublist))

(defun popup-item-documentation (item)
  (let ((doc (popup-item-document item)))
    (if (functionp doc)
        (setq doc (funcall doc (popup-item-value-or-self item))))
    doc))

(defun popup-item-show-help-1 (item)
  (let ((doc (popup-item-documentation item)))
    (when doc
      (with-current-buffer (get-buffer-create " *Popup Help*")
        (erase-buffer)
        (insert doc)
        (goto-char (point-min))
        (display-buffer (current-buffer)))
      t)))

(defun popup-item-show-help (item &optional persist)
  (when item
    (if (not persist)
        (save-window-excursion
          (when (popup-item-show-help-1 item)
            (block nil
              (while t
                (clear-this-command-keys)
                (let ((key (read-key-sequence-vector nil)))
                  (case (key-binding key)
                    ('scroll-other-window
                     (scroll-other-window))
                    ('scroll-other-window-down
                     (scroll-other-window-down nil))
                    (t
                     (setq unread-command-events (append key unread-command-events))
                     (return))))))))
      (popup-item-show-help-1 item))))

(defun popup-set-list (popup list)
  (popup-set-filtered-list popup list)
  (setf (popup-pattern popup) nil)
  (setf (popup-original-list popup) list))
  
(defun popup-set-filtered-list (popup list)
  (setf (popup-list popup) list
        (popup-offset popup) (if (> (popup-direction popup) 0)
                                 0
                               (max (- (popup-height popup) (length list)) 0))))

(defun popup-selected-item (popup)
  (nth (popup-cursor popup) (popup-list popup)))

(defun popup-selected-line (popup)
  (- (popup-cursor popup) (popup-scroll-top popup)))

(defun popup-line-overlay (popup line)
  (aref (popup-overlays popup) line))

(defun popup-selected-line-overlay (popup)
  (popup-line-overlay popup (popup-selected-line popup)))

(defun popup-hide-line (popup line)
  (let ((overlay (popup-line-overlay popup line)))
    (overlay-put overlay 'display nil)
    (overlay-put overlay 'after-string nil)))

(defun popup-line-hidden-p (popup line)
  (let ((overlay (popup-line-overlay popup line)))
    (and (eq (overlay-get overlay 'display) nil)
         (eq (overlay-get overlay 'after-string) nil))))

(defun popup-set-line-item (popup line item face margin-left margin-right scroll-bar-char symbol summary)
  (let* ((overlay (popup-line-overlay popup line))
         (content (popup-create-line-string popup (popup-x-to-string item) margin-left margin-right symbol summary))
         (start 0)
         (prefix (overlay-get overlay 'prefix))
         (postfix (overlay-get overlay 'postfix))
         end)
    ;; Overlap face properties
    (if (get-text-property start 'face content)
        (setq start (next-single-property-change start 'face content)))
    (while (and start (setq end (next-single-property-change start 'face content)))
      (put-text-property start end 'face face content)
      (setq start (next-single-property-change end 'face content)))
    (if start
        (put-text-property start (length content) 'face face content))
    (unless (overlay-get overlay 'dangle)
      (overlay-put overlay 'display (concat prefix (substring content 0 1)))
      (setq prefix nil
            content (concat (substring content 1))))
    (overlay-put overlay
                 'after-string
                 (concat prefix
                         content
                         scroll-bar-char
                         postfix))))

(defun popup-create-line-string (popup string margin-left margin-right symbol summary)
  (let* ((popup-width (popup-width popup))
         (summary-width (string-width summary))
         (string (car (popup-substring-by-width string
                                                (- popup-width
                                                   (if (> summary-width 0)
                                                       (+ summary-width 2)
                                                     0)))))
         (string-width (string-width string)))
    (concat margin-left
            string
            (make-string (max (- popup-width string-width summary-width) 0) ? )
            summary
            symbol
            margin-right)))

(defun popup-live-p (popup)
  (and popup (popup-overlays popup) t))

(defun popup-child-point (popup &optional offset)
  (overlay-end (popup-line-overlay popup
                                   (or offset
                                       (popup-selected-line popup)))))

(defun* popup-create (point
                      width
                      height
                      &key
                      min-height
                      around
                      (face 'popup-face)
                      (selection-face face)
                      scroll-bar
                      margin-left
                      margin-right
                      symbol
                      parent
                      parent-offset)
  (or margin-left (setq margin-left 0))
  (or margin-right (setq margin-right 0))
  (unless point
    (setq point
          (if parent (popup-child-point parent parent-offset) (point))))

  (save-excursion
    (goto-char point)
    (let* ((row (line-number-at-pos))
           (column (popup-current-physical-column))
           (overlays (make-vector height nil))
           (popup-width (+ width
                           (if scroll-bar 1 0)
                           margin-left
                           margin-right
                           (if symbol 2 0)))
           margin-left-cancel
           (window (selected-window))
           (window-start (window-start))
           (window-hscroll (window-hscroll))
           (window-width (window-width))
           (right (+ column popup-width))
           (overflow (and (> right window-width)
                          (>= right popup-width)))
           (foldable (and (null parent)
                          (>= column popup-width)))
           (direction (or
                       ;; Currently the direction of cascade popup won't be changed
                       (and parent (popup-direction parent))

                       ;; Calculate direction
                       (if (and (> row height)
                                (> height (- (max 1 (- (window-height)
                                                       (if mode-line-format 1 0)
                                                       (if header-line-format 1 0)))
                                             (count-lines window-start (point)))))
                           -1
                         1)))
           (depth (if parent (1+ (popup-depth parent)) 0))
           (newlines (max 0 (+ (- height (count-lines point (point-max))) (if around 1 0))))
           current-column)
      (when (> newlines 0)
        (popup-save-buffer-state
          (goto-char (point-max))
          (insert (make-string newlines ?\n))))
      
      (if overflow
          (if foldable
              (progn
                (decf column (- popup-width margin-left margin-right))
                (unless around (move-to-column column)))
            (when (not truncate-lines)
              ;; Cut out overflow
              (let ((d (1+ (- popup-width (- window-width column)))))
                (decf popup-width d)
                (decf width d)))
            (decf column margin-left))
        (decf column margin-left))
      (when (and (null parent)
                 (< column 0))
          ;; Cancel margin left
        (setq column 0)
        (decf popup-width margin-left)
        (setq margin-left-cancel t))
      
      (dotimes (i height)
        (let (overlay begin w (dangle t) (prefix "") (postfix ""))
          (when around
            (if (>= emacs-major-version 23)
                (vertical-motion (cons column direction))
              (vertical-motion direction)
              (move-to-column (+ (current-column) column))))
	  (setq around t
                current-column (popup-current-physical-column))

          (when (> current-column column)
            (backward-char)
            (setq current-column (popup-current-physical-column)))
          (when (< current-column column)
            ;; Extend short buffer lines by popup prefix (line of spaces)
            (setq prefix (make-string (+ (if (= current-column 0)
                                             (- window-hscroll (current-column))
                                           0)
                                         (- column current-column))
                                      ? )))

          (setq begin (point))
          (setq w (+ popup-width (length prefix)))
          (while (and (not (eolp)) (> w 0))
            (setq dangle nil)
            (decf w (char-width (char-after)))
            (forward-char))
          (if (< w 0)
              (setq postfix (make-string (- w) ? )))

          (setq overlay (make-overlay begin (point)))
          (overlay-put overlay 'window window)
          (overlay-put overlay 'dangle dangle)
          (overlay-put overlay 'prefix prefix)
          (overlay-put overlay 'postfix postfix)
          (overlay-put overlay 'width width)
          (aset overlays
		(if (> direction 0) i (- height i 1))
		overlay)))
      (loop for p from (- 10000 (* depth 1000))
            for overlay in (nreverse (append overlays nil))
            do (overlay-put overlay 'priority p))
      (let ((it (make-popup :point point
                            :row row
                            :column column
                            :width width
                            :height height
                            :min-height min-height
                            :direction direction
                            :parent parent
                            :depth depth
                            :face face
                            :selection-face selection-face
                            :margin-left margin-left
                            :margin-right margin-right
                            :margin-left-cancel margin-left-cancel
                            :scroll-bar scroll-bar
                            :symbol symbol
                            :cursor 0
                            :scroll-top 0
                            :current-height 0
                            :list nil
                            :newlines newlines
                            :overlays overlays)))
        (push it popup-instances)
        it))))

(defun popup-delete (popup)
  (when (popup-live-p popup)
    (popup-hide popup)
    (mapc 'delete-overlay (popup-overlays popup))
    (setf (popup-overlays popup) nil)
    (setq popup-instances (delq popup popup-instances))
    (let ((newlines (popup-newlines popup)))
      (when (> newlines 0)
        (popup-save-buffer-state
          (goto-char (point-max))
          (dotimes (i newlines)
            (if (= (char-before) ?\n)
                (delete-char -1)))))))
  nil)

(defun popup-draw (popup)
  (loop with height = (popup-height popup)
        with min-height = (popup-min-height popup)
        with popup-face = (popup-face popup)
        with selection-face = (popup-selection-face popup)
        with list = (popup-list popup)
        with length = (length list)
        with thum-size = (max (/ (* height height) (max length 1)) 1)
        with page-size = (/ (+ 0.0 (max length 1)) height)
        with scroll-bar = (popup-scroll-bar popup)
        with margin-left = (make-string (if (popup-margin-left-cancel popup) 0 (popup-margin-left popup)) ? )
        with margin-right = (make-string (popup-margin-right popup) ? )
        with symbol = (popup-symbol popup)
        with cursor = (popup-cursor popup)
        with scroll-top = (popup-scroll-top popup)
        with offset = (popup-offset popup)
        for o from offset
        for i from scroll-top
        while (< o height)
        for item in (nthcdr scroll-top list)
        for page-index = (* thum-size (/ o thum-size))
        for face = (if (= i cursor)
                       (or (popup-item-selection-face item) selection-face)
                     (or (popup-item-popup-face item) popup-face))
        for empty-char = (propertize " " 'face face)
        for scroll-bar-char = (if scroll-bar
                                  (cond
                                   ((<= page-size 1)
                                    empty-char)
                                   ((and (> page-size 1)
                                         (>= cursor (* page-index page-size))
                                         (< cursor (* (+ page-index thum-size) page-size)))
                                    popup-scroll-bar-foreground-char)
                                   (t
                                    popup-scroll-bar-background-char))
                                "")
        for sym = (if symbol
                      (concat " " (or (popup-item-symbol item) " "))
                    "")
        for summary = (or (popup-item-summary item) "")
        
        do
        ;; Show line and set item to the line
        (popup-set-line-item popup o item face margin-left margin-right scroll-bar-char sym summary)
        
        finally
        ;; Remember current height
        (setf (popup-current-height popup) (- o offset))

        ;; Hide remaining lines
        (let ((scroll-bar-char (if scroll-bar (propertize " " 'face popup-face) ""))
              (symbol (if symbol " " "")))
          (if (> (popup-direction popup) 0)
              (progn
                (when min-height
                  (while (< o min-height)
                    (popup-set-line-item popup o "" popup-face margin-left margin-right scroll-bar-char symbol "")
                    (incf o)))
                (while (< o height)
                  (popup-hide-line popup o)
                  (incf o)))
            (loop with h = (if min-height (- height min-height) offset)
                  for o from 0 below offset
                  if (< o h)
                  do (popup-hide-line popup o)
                  if (>= o h)
                  do (popup-set-line-item popup o "" popup-face margin-left margin-right scroll-bar-char symbol ""))))))

(defun popup-hide (popup)
  (dotimes (i (popup-height popup))
    (popup-hide-line popup i)))

(defun popup-hidden-p (popup)
  (let ((hidden t))
    (when (popup-live-p popup)
      (dotimes (i (popup-height popup))
        (unless (popup-line-hidden-p popup i)
          (setq hidden nil))))
    hidden))

(defun popup-select (popup i)
  (setq i (+ i (popup-offset popup)))
  (when (and (<= 0 i) (< i (popup-height popup)))
    (setf (popup-cursor popup) i)
    (popup-draw popup)
    t))

(defun popup-next (popup)
  (let ((height (popup-height popup))
        (cursor (1+ (popup-cursor popup)))
        (scroll-top (popup-scroll-top popup))
        (length (length (popup-list popup))))
    (cond
     ((>= cursor length)
      ;; Back to first page
      (setq cursor 0
            scroll-top 0))
     ((= cursor (+ scroll-top height))
      ;; Go to next page
      (setq scroll-top (min (1+ scroll-top) (max (- length height) 0)))))
    (setf (popup-cursor popup) cursor
          (popup-scroll-top popup) scroll-top)
    (popup-draw popup)))

(defun popup-previous (popup)
  (let ((height (popup-height popup))
        (cursor (1- (popup-cursor popup)))
        (scroll-top (popup-scroll-top popup))
        (length (length (popup-list popup))))
    (cond
     ((< cursor 0)
      ;; Go to last page
      (setq cursor (1- length)
            scroll-top (max (- length height) 0)))
     ((= cursor (1- scroll-top))
      ;; Go to previous page
      (decf scroll-top)))
    (setf (popup-cursor popup) cursor
          (popup-scroll-top popup) scroll-top)
    (popup-draw popup)))

(defun popup-scroll-down (popup &optional n)
  (let ((scroll-top (min (+ (popup-scroll-top popup) (or n 1))
                         (- (length (popup-list popup)) (popup-height popup)))))
    (setf (popup-cursor popup) scroll-top
          (popup-scroll-top popup) scroll-top)
    (popup-draw popup)))

(defun popup-scroll-up (popup &optional n)
  (let ((scroll-top (max (- (popup-scroll-top popup) (or n 1))
                         0)))
    (setf (popup-cursor popup) scroll-top
          (popup-scroll-top popup) scroll-top)
    (popup-draw popup)))



;; Popup isearch

(defface popup-isearch-match
  '((t (:background "sky blue")))
  "Popup isearch match face."
  :group 'popup)

(defvar popup-isearch-cursor-color "blue")

(defvar popup-isearch-keymap
  (let ((map (make-sparse-keymap)))
    ;(define-key map "\r"        'popup-isearch-done)
    (define-key map "\C-g"      'popup-isearch-cancel)
    (define-key map "\C-h"      'popup-isearch-delete)
    (define-key map (kbd "DEL") 'popup-isearch-delete)
    map))

(defsubst popup-isearch-char-p (char)
  (and (integerp char)
       (<= 32 char)
       (<= char 126)))

(defun popup-isearch-filter-list (pattern list)
  (loop with regexp = (regexp-quote pattern)
        for item in list
        do
        (unless (stringp item)
          (setq item (popup-item-propertize (popup-x-to-string item)
                                            'value item)))
        if (string-match regexp item)
        collect (let ((beg (match-beginning 0))
                      (end (match-end 0)))
                  (alter-text-property 0 (length item) 'face
                                       (lambda (prop)
                                         (unless (eq prop 'popup-isearch-match)
                                           prop))
                                       item)
                  (put-text-property beg end
                                     'face 'popup-isearch-match
                                     item)
                  item)))

(defun popup-isearch-prompt (popup pattern)
  (format "Pattern: %s" (if (= (length (popup-list popup)) 0)
                            (propertize pattern 'face 'isearch-fail)
                          pattern)))

(defun popup-isearch-update (popup pattern &optional callback)
  (setf (popup-cursor popup) 0
        (popup-scroll-top popup) 0
        (popup-pattern popup) pattern)
  (let ((list (popup-isearch-filter-list pattern (popup-original-list popup))))
    (popup-set-filtered-list popup list)
    (if callback
        (funcall callback list)))
  (popup-draw popup))

(defun* popup-isearch (popup
                       &key
                       (cursor-color popup-isearch-cursor-color)
                       (keymap popup-isearch-keymap)
                       callback
                       help-delay)
  (let ((list (popup-original-list popup))
        (pattern (or (popup-pattern popup) ""))
        (old-cursor-color (frame-parameter (selected-frame) 'cursor-color))
        prompt key binding done)
    (unwind-protect
        (unless (block nil
                  (if cursor-color
                      (set-cursor-color cursor-color))
                  (while t
                    (setq prompt (popup-isearch-prompt popup pattern))
                    (setq key (popup-menu-read-key-sequence keymap prompt help-delay))
                    (if (null key)
                        (unless (funcall popup-menu-show-quick-help-function popup nil :prompt prompt)
                          (clear-this-command-keys)
                          (push (read-event prompt) unread-command-events))
                      (setq binding (lookup-key keymap key))
                      (cond
                       ((and (stringp key)
                             (popup-isearch-char-p (aref key 0)))
                        (setq pattern (concat pattern key)))
                       ((eq binding 'popup-isearch-done)
                        (return t))
                       ((eq binding 'popup-isearch-cancel)
                        (return nil))
                       ((eq binding 'popup-isearch-delete)
                        (if (> (length pattern) 0)
                            (setq pattern (substring pattern 0 (1- (length pattern))))))
                       (t
                        (setq unread-command-events
                              (append (listify-key-sequence key) unread-command-events))
                        (return t)))
                      (popup-isearch-update popup pattern callback))))
          (popup-isearch-update popup "" callback)
          t) ; Return non-nil if isearch is cancelled
      (if old-cursor-color
          (set-cursor-color old-cursor-color)))))



;; Popup tip

(defface popup-tip-face
  '((t (:background "khaki1" :foreground "black")))
  "Face for popup tip."
  :group 'popup)

(defvar popup-tip-max-width 80)

(defun* popup-tip (string
                   &key
                   point
                   (around t)
                   width
                   (height 15)
                   min-height
                   truncate
                   margin
                   margin-left
                   margin-right
                   scroll-bar
                   parent
                   parent-offset
                   nowait
                   prompt
                   &aux tip lines)
  (if (bufferp string)
      (setq string (with-current-buffer string (buffer-string))))
  ;; TODO strip text (mainly face) properties
  (setq string (substring-no-properties string))

  (and (eq margin t) (setq margin 1))
  (or margin-left (setq margin-left margin))
  (or margin-right (setq margin-right margin))
  
  (let ((it (popup-fill-string string width popup-tip-max-width)))
    (setq width (car it)
          lines (cdr it)))
  
  (setq tip (popup-create point width height
                          :min-height min-height
                          :around around
                          :margin-left margin-left
                          :margin-right margin-right
                          :scroll-bar scroll-bar
                          :face 'popup-tip-face
                          :parent parent
                          :parent-offset parent-offset))

  (unwind-protect
      (when (> (popup-width tip) 0)                   ; not to be corrupted
        (when (and (not (eq width (popup-width tip))) ; truncated
                   (not truncate))
          ;; Refill once again to lines be fitted to popup width
          (setq width (popup-width tip))
          (setq lines (cdr (popup-fill-string string width width))))

        (popup-set-list tip lines)
        (popup-draw tip)
        (if nowait
            tip
          (clear-this-command-keys)
          (push (read-event prompt) unread-command-events)
          t))
    (unless nowait
      (popup-delete tip))))



;; Popup menu

(defface popup-menu-face
  '((t (:background "lightgray" :foreground "black")))
  "Face for popup menu."
  :group 'popup)

(defface popup-menu-selection-face
  '((t (:background "steelblue" :foreground "white")))
  "Face for popup menu selection."
  :group 'popup)

(defvar popup-menu-show-tip-function 'popup-tip
  "Function used for showing tooltip by `popup-menu-show-quick-help'.")

(defvar popup-menu-show-quick-help-function 'popup-menu-show-quick-help
  "Function used for showing quick help by `popup-menu*'.")

(defun popup-menu-show-help (menu &optional persist item)
  (popup-item-show-help (or item (popup-selected-item menu)) persist))

(defun popup-menu-documentation (menu &optional item)
  (popup-item-documentation (or item (popup-selected-item menu))))

(defun popup-menu-show-quick-help (menu &optional item &rest args)
  (let* ((point (plist-get args :point))
         (height (or (plist-get args :height) (popup-height menu)))
         (min-height (min height (popup-current-height menu)))
         (around nil)
         (parent-offset (popup-offset menu))
         (doc (popup-menu-documentation menu item)))
    (when (stringp doc)
      (if (popup-hidden-p menu)
          (setq around t
                menu nil
                parent-offset nil)
        (setq point nil))
      (let ((popup-use-optimized-column-computation nil)) ; To avoid wrong positioning
        (apply popup-menu-show-tip-function
               doc
               :point point
               :height height
               :min-height min-height
               :around around
               :parent menu
               :parent-offset parent-offset
               args)))))

(defun popup-menu-read-key-sequence (keymap &optional prompt timeout)
  (catch 'timeout
    (let ((timer (and timeout
                      (run-with-timer timeout nil
                                      (lambda ()
                                        (if (zerop (length (this-command-keys)))
                                            (throw 'timeout nil))))))
          (old-global-map (current-global-map))
          (temp-global-map (make-sparse-keymap))
          (overriding-terminal-local-map (make-sparse-keymap)))
      (substitute-key-definition 'keyboard-quit 'keyboard-quit
                                 temp-global-map old-global-map)
      (define-key temp-global-map [menu-bar] (lookup-key old-global-map [menu-bar]))
      (define-key temp-global-map [tool-bar] (lookup-key old-global-map [tool-bar]))
      (set-keymap-parent overriding-terminal-local-map keymap)
      (if (current-local-map)
          (define-key overriding-terminal-local-map [menu-bar]
            (lookup-key (current-local-map) [menu-bar])))
      (unwind-protect
          (progn
            (use-global-map temp-global-map)
            (clear-this-command-keys)
            (with-temp-message prompt
              (read-key-sequence nil)))
        (use-global-map old-global-map)
        (if timer (cancel-timer timer))))))

(defun popup-menu-fallback (event default))

(defun* popup-menu-event-loop (menu keymap fallback &optional prompt help-delay isearch isearch-cursor-color isearch-keymap isearch-callback &aux key binding)
  (block nil
    (while (popup-live-p menu)
      (and isearch
           (popup-isearch menu
                          :cursor-color isearch-cursor-color
                          :keymap isearch-keymap
                          :callback isearch-callback
                          :help-delay help-delay)
           (keyboard-quit))
      (setq key (popup-menu-read-key-sequence keymap prompt help-delay))
      (if (null key)
          (unless (funcall popup-menu-show-quick-help-function menu nil :prompt prompt)
            (clear-this-command-keys)
            (push (read-event prompt) unread-command-events))
        (if (eq (lookup-key (current-global-map) key) 'keyboard-quit)
            (keyboard-quit))
        (setq binding (lookup-key keymap key))
        (cond
         ((eq binding 'popup-close)
          (if (popup-parent menu)
              (return)))
         ((memq binding '(popup-select popup-open))
          (let* ((item (popup-selected-item menu))
                 (sublist (popup-item-sublist item)))
            (if sublist
                (popup-aif (popup-cascade-menu sublist
                                               :around nil
                                               :parent menu
                                               :margin-left (popup-margin-left menu)
                                               :margin-right (popup-margin-right menu)
                                               :scroll-bar (popup-scroll-bar menu))
                    (and it (return it)))
              (if (eq binding 'popup-select)
                  (return (popup-item-value-or-self item))))))
         ((eq binding 'popup-next)
          (popup-next menu))
         ((eq binding 'popup-previous)
          (popup-previous menu))
         ((eq binding 'popup-help)
          (popup-menu-show-help menu))
         ((eq binding 'popup-isearch)
          (popup-isearch menu
                         :cursor-color isearch-cursor-color
                         :keymap isearch-keymap
                         :callback isearch-callback
                         :help-delay help-delay))
         ((commandp binding)
          (call-interactively binding))
         (t
          (funcall fallback key (key-binding key))))))))

;; popup-menu is used by mouse.el unfairly...
(defun* popup-menu* (list
                     &key
                     point
                     (around t)
                     (width (popup-preferred-width list))
                     (height 15)
                     margin
                     margin-left
                     margin-right
                     scroll-bar
                     symbol
                     parent
                     parent-offset
                     (keymap popup-menu-keymap)
                     (fallback 'popup-menu-fallback)
                     help-delay
                     prompt
                     isearch
                     (isearch-cursor-color popup-isearch-cursor-color)
                     (isearch-keymap popup-isearch-keymap)
                     isearch-callback
                     &aux menu event)
  (and (eq margin t) (setq margin 1))
  (or margin-left (setq margin-left margin))
  (or margin-right (setq margin-right margin))
  (if (and scroll-bar
           (integerp margin-right)
           (> margin-right 0))
      ;; Make scroll-bar space as margin-right
      (decf margin-right))
  (setq menu (popup-create point width height
                           :around around
                           :face 'popup-menu-face
                           :selection-face 'popup-menu-selection-face
                           :margin-left margin-left
                           :margin-right margin-right
                           :scroll-bar scroll-bar
                           :symbol symbol
                           :parent parent))
  (unwind-protect
      (progn
        (popup-set-list menu list)
        (popup-draw menu)
        (popup-menu-event-loop menu keymap fallback prompt help-delay isearch
                               isearch-cursor-color isearch-keymap isearch-callback))
    (popup-delete menu)))

(defun popup-cascade-menu (list &rest args)
  "Same to `popup-menu', but an element of `LIST' can be
list of submenu."
  (apply 'popup-menu*
         (mapcar (lambda (item)
                   (if (consp item)
                       (popup-make-item (car item)
                                        :sublist (cdr item)
                                        :symbol ">")
                     item))
                 list)
         :symbol t
         args))

(defvar popup-menu-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "\r"        'popup-select)
    (define-key map "\C-f"      'popup-open)
    (define-key map [right]     'popup-open)
    (define-key map "\C-b"      'popup-close)
    (define-key map [left]      'popup-close)

    (define-key map "\C-n"      'popup-next)
    (define-key map [down]      'popup-next)
    (define-key map "\C-p"      'popup-previous)
    (define-key map [up]        'popup-previous)

    (define-key map [f1]        'popup-help)
    (define-key map (kbd "\C-?") 'popup-help)

    (define-key map "\C-s"      'popup-isearch)
    map))

(provide 'popup)
;;; popup.el ends here


;;;; Global stuff

(defun ac-error (&optional var)
  "Report an error and disable `auto-complete-mode'."
  (ignore-errors
    (message "auto-complete error: %s" var)
    (auto-complete-mode -1)
    var))



;;;; Customization

(defgroup auto-complete nil
  "Auto completion."
  :group 'completion
  :prefix "ac-")

(defcustom ac-delay 0.1
  "Delay to completions will be available."
  :type 'float
  :group 'auto-complete)

(defcustom ac-auto-show-menu 0.8
  "Non-nil means completion menu will be automatically shown."
  :type '(choice (const :tag "Yes" t)
                 (const :tag "Never" nil)
                 (float :tag "Timer"))
  :group 'auto-complete)

(defcustom ac-show-menu-immediately-on-auto-complete t
  "Non-nil means menu will be showed immediately on `auto-complete'."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-expand-on-auto-complete t
  "Non-nil means expand whole common part on first time `auto-complete'."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-disable-faces '(font-lock-comment-face font-lock-string-face font-lock-doc-face)
  "Non-nil means disable automatic completion on specified faces."
  :type '(repeat symbol)
  :group 'auto-complete)

(defcustom ac-stop-flymake-on-completing t
  "Non-nil means disble flymake temporarily on completing."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-use-fuzzy t
  "Non-nil means use fuzzy matching."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-fuzzy-cursor-color "red"
  "Cursor color in fuzzy mode."
  :type 'string
  :group 'auto-complete)

(defcustom ac-use-comphist t
  "Non-nil means use intelligent completion history."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-comphist-threshold 0.7
  "Percentage of ignoring low scored candidates."
  :type 'float
  :group 'auto-complete)

(defcustom ac-comphist-file
  (expand-file-name (concat (if (boundp 'user-emacs-directory)
                                user-emacs-directory
                              "~/.emacs.d/")
                            "/ac-comphist.dat"))
  "Completion history file name."
  :type 'string
  :group 'auto-complete)

(defcustom ac-use-quick-help t
  "Non-nil means use quick help."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-quick-help-delay 1.5
  "Delay to show quick help."
  :type 'float
  :group 'auto-complete)

(defcustom ac-menu-height 10
  "Max height of candidate menu."
  :type 'integer
  :group 'auto-complete)
(defvaralias 'ac-candidate-menu-height 'ac-menu-height)

(defcustom ac-quick-help-height 20
  "Max height of quick help."
  :type 'integer
  :group 'auto-complete)

(defcustom ac-quick-help-prefer-x t
  "Prefer X tooltip than overlay popup for displaying quick help."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-candidate-limit nil
  "Limit number of candidates. Non-integer means no limit."
  :type 'integer
  :group 'auto-complete)
(defvaralias 'ac-candidate-max 'ac-candidate-limit)

(defcustom ac-modes
  '(emacs-lisp-mode
    lisp-interaction-mode
    c-mode cc-mode c++-mode
    java-mode clojure-mode scala-mode
    scheme-mode
    ocaml-mode tuareg-mode
    perl-mode cperl-mode python-mode ruby-mode
    ecmascript-mode javascript-mode js-mode js2-mode php-mode css-mode
    makefile-mode sh-mode fortran-mode f90-mode ada-mode
    xml-mode sgml-mode)
  "Major modes `auto-complete-mode' can run on."
  :type '(repeat symbol)
  :group 'auto-complete)

(defcustom ac-compatible-packages-regexp
  "^ac-"
  "Regexp to indicate what packages can work with auto-complete."
  :type 'string
  :group 'auto-complete)

(defcustom ac-trigger-commands
  '(self-insert-command)
  "Trigger commands that specify whether `auto-complete' should start or not."
  :type '(repeat symbol)
  :group 'auto-complete)

(defcustom ac-trigger-commands-on-completing
  '(delete-backward-char
    backward-delete-char
    backward-delete-char-untabify)
  "Trigger commands that specify whether `auto-complete' should continue or not."
  :type '(repeat symbol)
  :group 'auto-complete)

(defcustom ac-trigger-key nil
  "Non-nil means `auto-complete' will start by typing this key.
If you specify this TAB, for example, `auto-complete' will start by typing TAB,
and if there is no completions, an original command will be fallbacked."
  :type 'string
  :group 'auto-complete
  :set (lambda (symbol value)
         (set-default symbol value)
         (when (and value
                    (fboundp 'ac-set-trigger-key))
           (ac-set-trigger-key value))))

(defcustom ac-auto-start 2
  "Non-nil means completion will be started automatically.
Positive integer means if a length of a word you entered is larger than the value,
completion will be started automatically.
If you specify `nil', never be started automatically."
  :type '(choice (const :tag "Yes" t)
                 (const :tag "Never" nil)
                 (integer :tag "Require"))
  :group 'auto-complete)

(defcustom ac-ignores nil
  "List of string to ignore completion."
  :type '(repeat string)
  :group 'auto-complete)

(defcustom ac-ignore-case 'smart
  "Non-nil means auto-complete ignores case.
If this value is `smart', auto-complete ignores case only when
a prefix doen't contain any upper case letters."
  :type '(choice (const :tag "Yes" t)
                 (const :tag "Smart" smart)
                 (const :tag "No" nil))
  :group 'auto-complete)

(defcustom ac-dwim t
  "Non-nil means `auto-complete' works based on Do What I Mean."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-use-menu-map nil
  "Non-nil means a special keymap `ac-menu-map' on completing menu will be used."
  :type 'boolean
  :group 'auto-complete)

(defcustom ac-use-overriding-local-map nil
  "Non-nil means `overriding-local-map' will be used to hack for overriding key events on auto-copletion."
  :type 'boolean
  :group 'auto-complete)

(defface ac-completion-face
  '((t (:foreground "darkgray" :underline t)))
  "Face for inline completion"
  :group 'auto-complete)

(defface ac-candidate-face
  '((t (:background "lightgray" :foreground "black")))
  "Face for candidate."
  :group 'auto-complete)

(defface ac-selection-face
  '((t (:background "steelblue" :foreground "white")))
  "Face for selected candidate."
  :group 'auto-complete)

(defvar auto-complete-mode-hook nil
  "Hook for `auto-complete-mode'.")



;;;; Internal variables

(defvar auto-complete-mode nil
  "Dummy variable to suppress compiler warnings.")

(defvar ac-cursor-color nil
  "Old cursor color.")

(defvar ac-inline nil
  "Inline completion instance.")

(defvar ac-menu nil
  "Menu instance.")

(defvar ac-show-menu nil
  "Flag to show menu on timer tick.")

(defvar ac-last-completion nil
  "Cons of prefix marker and selected item of last completion.")

(defvar ac-quick-help nil
  "Quick help instance")

(defvar ac-completing nil
  "Non-nil means `auto-complete-mode' is now working on completion.")

(defvar ac-buffer nil
  "Buffer where auto-complete is started.")

(defvar ac-point nil
  "Start point of prefix.")

(defvar ac-last-point nil
  "Last point of updating pattern.")

(defvar ac-prefix nil
  "Prefix string.")
(defvaralias 'ac-target 'ac-prefix)

(defvar ac-selected-candidate nil
  "Last selected candidate.")

(defvar ac-common-part nil
  "Common part string of meaningful candidates.
If there is no common part, this will be nil.")

(defvar ac-whole-common-part nil
  "Common part string of whole candidates.
If there is no common part, this will be nil.")

(defvar ac-prefix-overlay nil
  "Overlay for prefix string.")

(defvar ac-timer nil
  "Completion idle timer.")

(defvar ac-show-menu-timer nil
  "Show menu idle timer.")

(defvar ac-quick-help-timer nil
  "Quick help idle timer.")

(defvar ac-triggered nil
  "Flag to update.")

(defvar ac-limit nil
  "Limit number of candidates for each sources.")

(defvar ac-candidates nil
  "Current candidates.")

(defvar ac-candidates-cache nil
  "Candidates cache for individual sources.")

(defvar ac-fuzzy-enable nil
  "Non-nil means fuzzy matching is enabled.")

(defvar ac-dwim-enable nil
  "Non-nil means DWIM completion will be allowed.")

(defvar ac-mode-map (make-sparse-keymap)
  "Auto-complete mode map. It is also used for trigger key command. See also `ac-trigger-key'.")

(defvar ac-completing-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\t" 'ac-expand)
    (define-key map "\r" 'ac-complete)
    (define-key map (kbd "M-TAB") 'auto-complete)
    (define-key map "\C-s" 'ac-isearch)

    (define-key map "\M-n" 'ac-next)
    (define-key map "\M-p" 'ac-previous)
    (define-key map [down] 'ac-next)
    (define-key map [up] 'ac-previous)

    (define-key map [f1] 'ac-help)
    (define-key map [M-f1] 'ac-persist-help)
    (define-key map (kbd "C-?") 'ac-help)
    (define-key map (kbd "C-M-?") 'ac-persist-help)

    (define-key map [C-down] 'ac-quick-help-scroll-down)
    (define-key map [C-up] 'ac-quick-help-scroll-up)
    (define-key map "\C-\M-n" 'ac-quick-help-scroll-down)
    (define-key map "\C-\M-p" 'ac-quick-help-scroll-up)

    (dotimes (i 9)
      (let ((symbol (intern (format "ac-complete-%d" (1+ i)))))
        (fset symbol
              `(lambda ()
                 (interactive)
                 (when (and (ac-menu-live-p) (popup-select ac-menu ,i))
                   (ac-complete))))
        (define-key map (read-kbd-macro (format "M-%s" (1+ i))) symbol)))

    map)
  "Keymap for completion.")
(defvaralias 'ac-complete-mode-map 'ac-completing-map)

(defvar ac-menu-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-n" 'ac-next)
    (define-key map "\C-p" 'ac-previous)
    (set-keymap-parent map ac-completing-map)
    map)
  "Keymap for completion on completing menu.")

(defvar ac-current-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map ac-completing-map)
    map))

(defvar ac-match-function 'all-completions
  "Default match function.")

(defvar ac-prefix-definitions
  '((symbol . ac-prefix-symbol)
    (file . ac-prefix-file)
    (valid-file . ac-prefix-valid-file)
    (c-dot . ac-prefix-c-dot)
    (c-dot-ref . ac-prefix-c-dot-ref))
  "Prefix definitions for common use.")

(defvar ac-sources '(ac-source-words-in-same-mode-buffers)
  "Sources for completion.")
(make-variable-buffer-local 'ac-sources)

(defvar ac-compiled-sources nil
  "Compiled source of `ac-sources'.")

(defvar ac-current-sources nil
  "Current working sources. This is sublist of `ac-compiled-sources'.")

(defvar ac-omni-completion-sources nil
  "Do not use this anymore.")

(defvar ac-current-prefix-def nil)

(defvar ac-ignoring-prefix-def nil)



;;;; Intelligent completion history

(defvar ac-comphist nil
  "Database of completion history.")

(defsubst ac-comphist-make-tab ()
  (make-hash-table :test 'equal))

(defsubst ac-comphist-tab (db)
  (nth 0 db))

(defsubst ac-comphist-cache (db)
  (nth 1 db))

(defun ac-comphist-make (&optional tab)
  (list (or tab (ac-comphist-make-tab)) (make-hash-table :test 'equal :weakness t)))

(defun ac-comphist-get (db string &optional create)
  (let* ((tab (ac-comphist-tab db))
         (index (gethash string tab)))
    (when (and create (null index))
      (setq index (make-vector (length string) 0))
      (puthash string index tab))
    index))

(defun ac-comphist-add (db string prefix)
  (setq prefix (min prefix (1- (length string))))
  (when (<= 0 prefix)
    (setq string (substring-no-properties string))
    (let ((stat (ac-comphist-get db string t)))
      (incf (aref stat prefix))
      (remhash string (ac-comphist-cache db)))))

(defun ac-comphist-score (db string prefix)
  (setq prefix (min prefix (1- (length string))))
  (if (<= 0 prefix)
      (let ((cache (gethash string (ac-comphist-cache db))))
        (or (and cache (aref cache prefix))
            (let ((stat (ac-comphist-get db string))
                  (score 0.0))
              (when stat
                (loop for p from 0 below (length string)
                      ;; sigmoid function
                      with a = 5
                      with d = (/ 6.0 a)
                      for x = (- d (abs (- prefix p)))
                      for r = (/ 1.0 (1+ (exp (* (- a) x))))
                      do
                      (incf score (* (aref stat p) r))))
              ;; Weight by distance
              (incf score (max 0.0 (- 0.3 (/ (- (length string) prefix) 100.0))))
              (unless cache
                (setq cache (make-vector (length string) nil))
                (puthash string cache (ac-comphist-cache db)))
              (aset cache prefix score)
              score)))
    0.0))

(defun ac-comphist-sort (db collection prefix &optional threshold)
  (let (result
        (n 0)
        (total 0)
        (cur 0))
    (setq result (mapcar (lambda (a)
                           (when (and cur threshold)
                             (if (>= cur (* total threshold))
                                 (setq cur nil)
                               (incf n)
                               (incf cur (cdr a))))
                           (car a))
                         (sort (mapcar (lambda (string)
                                         (let ((score (ac-comphist-score db string prefix)))
                                           (incf total score)
                                           (cons string score)))
                                       collection)
                               (lambda (a b) (< (cdr b) (cdr a))))))
    (if threshold
        (cons n result)
      result)))

(defun ac-comphist-serialize (db)
  (let (alist)
    (maphash (lambda (k v)
               (push (cons k v) alist))
             (ac-comphist-tab db))
    (list alist)))

(defun ac-comphist-deserialize (sexp)
  (condition-case nil
      (ac-comphist-make (let ((tab (ac-comphist-make-tab)))
                          (mapc (lambda (cons)
                                  (puthash (car cons) (cdr cons) tab))
                                (nth 0 sexp))
                          tab))
    (error (message "Invalid comphist db.") nil)))

(defun ac-comphist-init ()
  (ac-comphist-load)
  (add-hook 'kill-emacs-hook 'ac-comphist-save))

(defun ac-comphist-load ()
  (interactive)
  (let ((db (if (file-exists-p ac-comphist-file)
                (ignore-errors
                  (with-temp-buffer
                    (insert-file-contents ac-comphist-file)
                    (goto-char (point-min))
                    (ac-comphist-deserialize (read (current-buffer))))))))
    (setq ac-comphist (or db (ac-comphist-make)))))

(defun ac-comphist-save ()
  (interactive)
  (require 'pp)
  (ignore-errors
    (with-temp-buffer
      (pp (ac-comphist-serialize ac-comphist) (current-buffer))
      (write-region (point-min) (point-max) ac-comphist-file))))



;;;; Auto completion internals

(defun ac-menu-at-wrapper-line-p ()
  "Return non-nil if current line is long and wrapped to next visual line."
  (and (not truncate-lines)
       (eq (line-beginning-position)
           (save-excursion
             (vertical-motion 1)
             (line-beginning-position)))))

(defun ac-prefix-symbol ()
  "Default prefix definition function."
  (require 'thingatpt)
  (car-safe (bounds-of-thing-at-point 'symbol)))
(defalias 'ac-prefix-default 'ac-prefix-symbol)

(defun ac-prefix-file ()
  "File prefix."
  (let ((point (re-search-backward "[\"<>' \t\r\n]" nil t)))
    (if point (1+ point))))

(defun ac-prefix-valid-file ()
  "Existed (or to be existed) file prefix."
  (let* ((line-beg (line-beginning-position))
         (end (point))
         (start (or (let ((point (re-search-backward "[\"<>'= \t\r\n]" line-beg t)))
                      (if point (1+ point)))
                    line-beg))
         (file (buffer-substring start end)))
    (if (and file (or (string-match "^/" file)
                      (and (setq file (and (string-match "^[^/]*/" file)
                                           (match-string 0 file)))
                           (file-directory-p file))))
        start)))

(defun ac-prefix-c-dot ()
  "C-like languages dot(.) prefix."
  (if (re-search-backward "\\.\\(\\(?:[a-zA-Z0-9][_a-zA-Z0-9]*\\)?\\)\\=" nil t)
      (match-beginning 1)))

(defun ac-prefix-c-dot-ref ()
  "C-like languages dot(.) and reference(->) prefix."
  (if (re-search-backward "\\(?:\\.\\|->\\)\\(\\(?:[a-zA-Z0-9][_a-zA-Z0-9]*\\)?\\)\\=" nil t)
      (match-beginning 1)))

(defun ac-define-prefix (name prefix)
  "Define new prefix definition.
You can not use it in source definition like (prefix . `NAME')."
  (push (cons name prefix) ac-prefix-definitions))

(defun ac-match-substring (prefix candidates)
  (loop with regexp = (regexp-quote prefix)
        for candidate in candidates
        if (string-match regexp candidate)
        collect candidate))

(defsubst ac-source-entity (source)
  (if (symbolp source)
      (symbol-value source)
    source))

(defun ac-source-available-p (source)
  (if (and (symbolp source)
           (get source 'available))
      (eq (get source 'available) t)
    (let* ((src (ac-source-entity source))
           (avail-pair (assq 'available src))
           (avail-cond (cdr avail-pair))
           (available (and (if avail-pair
                               (cond
                                ((symbolp avail-cond)
                                 (funcall avail-cond))
                                ((listp avail-cond)
                                 (eval avail-cond)))
                             t)
                           (loop for feature in (assoc-default 'depends src)
                                 unless (require feature nil t) return nil
                                 finally return t))))
      (if (symbolp source)
          (put source 'available (if available t 'no)))
      available)))

(defun ac-compile-sources (sources)
  "Compiled `SOURCES' into expanded sources style."
  (loop for source in sources
        if (ac-source-available-p source)
        do
        (setq source (ac-source-entity source))
        (flet ((add-attribute (name value &optional append) (add-to-list 'source (cons name value) append)))
          ;; prefix
          (let* ((prefix (assoc 'prefix source))
                 (real (assoc-default (cdr prefix) ac-prefix-definitions)))
            (cond
             (real
              (add-attribute 'prefix real))
             ((null prefix)
              (add-attribute 'prefix 'ac-prefix-default))))
          ;; match
          (let ((match (assq 'match source)))
            (cond
             ((eq (cdr match) 'substring)
              (setcdr match 'ac-match-substring)))))
        and collect source))

(defun ac-compiled-sources ()
  (or ac-compiled-sources
      (setq ac-compiled-sources
            (ac-compile-sources ac-sources))))

(defsubst ac-menu-live-p ()
  (popup-live-p ac-menu))

(defun ac-menu-create (point width height)
  (setq ac-menu
        (popup-create point width height
                      :around t
                      :face 'ac-candidate-face
                      :selection-face 'ac-selection-face
                      :symbol t
                      :scroll-bar t
                      :margin-left 1)))

(defun ac-menu-delete ()
  (when ac-menu
    (popup-delete ac-menu)
    (setq ac-menu)))

(defsubst ac-inline-marker ()
  (nth 0 ac-inline))

(defsubst ac-inline-overlay ()
  (nth 1 ac-inline))

(defsubst ac-inline-live-p ()
  (and ac-inline (ac-inline-overlay) t))

(defun ac-inline-show (point string)
  (unless ac-inline
    (setq ac-inline (list (make-marker) nil)))
  (save-excursion
    (let ((overlay (ac-inline-overlay))
          (width 0)
          (string-width (string-width string))
          (length 0)
          (original-string string))
      ;; Calculate string space to show completion
      (goto-char point)
      (let (c)
        (while (and (not (eolp))
                    (< width string-width)
                    (setq c (char-after))
                    (not (eq c ?\t)))   ; special case for tab
        (incf width (char-width c))
        (incf length)
        (forward-char)))

      ;; Show completion
      (goto-char point)
      (cond
       ((= width 0)
        (set-marker (ac-inline-marker) point)
        (let ((buffer-undo-list t))
          (insert " "))
        (setq width 1
              length 1))
       ((<= width string-width)
        ;; No space to show
        ;; Do nothing
        )
       ((> width string-width)
        ;; Need to fill space
        (setq string (concat string (make-string (- width string-width) ? )))))
      (setq string (propertize string 'face 'ac-completion-face))
      (if overlay
          (progn
            (move-overlay overlay point (+ point length))
            (overlay-put overlay 'invisible nil))
        (setq overlay (make-overlay point (+ point length)))
        (setf (nth 1 ac-inline)  overlay)
        (overlay-put overlay 'priority 9999)
        ;; Help prefix-overlay in some cases
        (overlay-put overlay 'keymap ac-current-map))
      (overlay-put overlay 'display (substring string 0 1))
      ;; TODO no width but char
      (overlay-put overlay 'after-string (substring string 1))
      (overlay-put overlay 'string original-string))))

(defun ac-inline-delete ()
  (when (ac-inline-live-p)
    (ac-inline-hide)
    (delete-overlay (ac-inline-overlay))
    (setq ac-inline nil)))

(defun ac-inline-hide ()
  (when (ac-inline-live-p)
    (let ((overlay (ac-inline-overlay))
          (marker (ac-inline-marker))
          (buffer-undo-list t))
      (when overlay
        (when (marker-position marker)
          (save-excursion
            (goto-char marker)
            (delete-char 1)
            (set-marker marker nil)))
        (move-overlay overlay (point-min) (point-min))
        (overlay-put overlay 'invisible t)
        (overlay-put overlay 'display nil)
        (overlay-put overlay 'after-string nil)))))

(defun ac-inline-update ()
  (if (and ac-completing ac-prefix (stringp ac-common-part))
      (let ((common-part-length (length ac-common-part))
            (prefix-length (length ac-prefix)))
        (if (> common-part-length prefix-length)
            (progn
              (ac-inline-hide)
              (ac-inline-show (point) (substring ac-common-part prefix-length)))
          (ac-inline-delete)))
    (ac-inline-delete)))

(defun ac-put-prefix-overlay ()
  (unless ac-prefix-overlay
    (let (newline)
      ;; Insert newline to make sure that cursor always on the overlay
      (when (and (eq ac-point (point-max))
                 (eq ac-point (point)))
        (popup-save-buffer-state
          (insert "\n"))
        (setq newline t))
      (setq ac-prefix-overlay (make-overlay ac-point (1+ (point)) nil t t))
      (overlay-put ac-prefix-overlay 'priority 9999)
      (overlay-put ac-prefix-overlay 'keymap (make-sparse-keymap))
      (overlay-put ac-prefix-overlay 'newline newline))))

(defun ac-remove-prefix-overlay ()
  (when ac-prefix-overlay
    (when (overlay-get ac-prefix-overlay 'newline)
      ;; Remove inserted newline
      (popup-save-buffer-state
        (goto-char (point-max))
        (if (eq (char-before) ?\n)
            (delete-char -1))))
    (delete-overlay ac-prefix-overlay)))

(defun ac-activate-completing-map ()
  (if (and ac-show-menu ac-use-menu-map)
      (set-keymap-parent ac-current-map ac-menu-map))
  (when (and ac-use-overriding-local-map
             (null overriding-terminal-local-map))
    (setq overriding-terminal-local-map ac-current-map))
  (when ac-prefix-overlay
    (set-keymap-parent (overlay-get ac-prefix-overlay 'keymap) ac-current-map)))

(defun ac-deactivate-completing-map ()
  (set-keymap-parent ac-current-map ac-completing-map)
  (when (and ac-use-overriding-local-map
             (eq overriding-terminal-local-map ac-current-map))
    (setq overriding-terminal-local-map nil))
  (when ac-prefix-overlay
    (set-keymap-parent (overlay-get ac-prefix-overlay 'keymap) nil)))

(defsubst ac-selected-candidate ()
  (if ac-menu
      (popup-selected-item ac-menu)))

(defun ac-prefix (requires ignore-list)
  (loop with current = (point)
        with point
        with prefix-def
        with sources
        for source in (ac-compiled-sources)
        for prefix = (assoc-default 'prefix source)
        for req = (or (assoc-default 'requires source) requires 1)

        if (null prefix-def)
        do
        (unless (member prefix ignore-list)
          (save-excursion
            (setq point (cond
                         ((symbolp prefix)
                          (funcall prefix))
                         ((stringp prefix)
                          (and (re-search-backward (concat prefix "\\=") nil t)
                               (or (match-beginning 1) (match-beginning 0))))
                         ((stringp (car-safe prefix))
                          (let ((regexp (nth 0 prefix))
                                (end (nth 1 prefix))
                                (group (nth 2 prefix)))
                            (and (re-search-backward (concat regexp "\\=") nil t)
                                 (funcall (if end 'match-end 'match-beginning)
                                          (or group 0)))))
                         (t
                          (eval prefix))))
            (if (and point
                     (integerp req)
                     (< (- current point) req))
                (setq point nil))
            (if point
                (setq prefix-def prefix))))
        
        if (equal prefix prefix-def) do (push source sources)

        finally return
        (and point (list prefix-def point (nreverse sources)))))

(defun ac-init ()
  "Initialize current sources to start completion."
  (setq ac-candidates-cache nil)
  (loop for source in ac-current-sources
        for function = (assoc-default 'init source)
        if function do
        (save-excursion
          (cond
           ((functionp function)
            (funcall function))
           (t
            (eval function))))))

(defun ac-candidates-1 (source)
  (let* ((do-cache (assq 'cache source))
         (function (assoc-default 'candidates source))
         (action (assoc-default 'action source))
         (document (assoc-default 'document source))
         (symbol (assoc-default 'symbol source))
         (ac-limit (or (assoc-default 'limit source) ac-limit))
         (face (or (assoc-default 'face source) (assoc-default 'candidate-face source)))
         (selection-face (assoc-default 'selection-face source))
         (cache (and do-cache (assq source ac-candidates-cache)))
         (candidates (cdr cache)))
    (unless cache
      (setq candidates (save-excursion
                         (cond
                          ((functionp function)
                           (funcall function))
                          (t
                           (eval function)))))
      ;; Convert (name value) format candidates into name with text properties.
      (setq candidates (mapcar (lambda (candidate)
                                 (if (consp candidate)
                                     (propertize (car candidate) 'value (cdr candidate))
                                   candidate))
                               candidates))
      (when do-cache
        (push (cons source candidates) ac-candidates-cache)))
    (setq candidates (funcall (or (assoc-default 'match source)
                                  ac-match-function)
                              ac-prefix candidates))
    ;; Remove extra items regarding to ac-limit
    (if (and (integerp ac-limit) (> ac-limit 1) (> (length candidates) ac-limit))
        (setcdr (nthcdr (1- ac-limit) candidates) nil))
    ;; Put candidate properties
    (setq candidates (mapcar (lambda (candidate)
                               (popup-item-propertize candidate
                                                      'action action
                                                      'symbol symbol
                                                      'document document
                                                      'popup-face face
                                                      'selection-face selection-face))
                             candidates))
    candidates))

(defun ac-candidates ()
  "Produce candidates for current sources."
  (loop with completion-ignore-case = (or (eq ac-ignore-case t)
                                          (and (eq ac-ignore-case 'smart)
                                               (let ((case-fold-search nil)) (not (string-match "[[:upper:]]" ac-prefix)))))
        with case-fold-search = completion-ignore-case
        with prefix-len = (length ac-prefix)
        for source in ac-current-sources
        append (ac-candidates-1 source) into candidates
        finally return
        (progn
          (delete-dups candidates)
          (if (and ac-use-comphist ac-comphist)
              (if ac-show-menu
                  (let* ((pair (ac-comphist-sort ac-comphist candidates prefix-len ac-comphist-threshold))
                         (n (car pair))
                         (result (cdr pair))
                         (cons (if (> n 0) (nthcdr (1- n) result)))
                         (cdr (cdr cons)))
                    (if cons (setcdr cons nil))
                    (setq ac-common-part (try-completion ac-prefix result))
                    (setq ac-whole-common-part (try-completion ac-prefix candidates))
                    (if cons (setcdr cons cdr))
                    result)
                (setq candidates (ac-comphist-sort ac-comphist candidates prefix-len))
                (setq ac-common-part (if candidates (popup-x-to-string (car candidates))))
                (setq ac-whole-common-part (try-completion ac-prefix candidates))
                candidates)
            (setq ac-common-part (try-completion ac-prefix candidates))
            (setq ac-whole-common-part ac-common-part)
            candidates))))

(defun ac-update-candidates (cursor scroll-top)
  "Update candidates of menu to `ac-candidates' and redraw it."
  (setf (popup-cursor ac-menu) cursor
        (popup-scroll-top ac-menu) scroll-top)
  (setq ac-dwim-enable (= (length ac-candidates) 1))
  (if ac-candidates
      (progn
        (setq ac-completing t)
        (ac-activate-completing-map))
    (setq ac-completing nil)
    (ac-deactivate-completing-map))
  (ac-inline-update)
  (popup-set-list ac-menu ac-candidates)
  (if (and (not ac-fuzzy-enable)
           (<= (length ac-candidates) 1))
      (popup-hide ac-menu)
    (if ac-show-menu
        (popup-draw ac-menu))))

(defun ac-reposition ()
  "Force to redraw candidate menu with current `ac-candidates'."
  (let ((cursor (popup-cursor ac-menu))
        (scroll-top (popup-scroll-top ac-menu)))
    (ac-menu-delete)
    (ac-menu-create ac-point (popup-preferred-width ac-candidates) (popup-height ac-menu))
    (ac-update-candidates cursor scroll-top)))

(defun ac-cleanup ()
  "Cleanup auto completion."
  (if ac-cursor-color
      (set-cursor-color ac-cursor-color))
  (when (and ac-use-comphist ac-comphist)
    (when (and (null ac-selected-candidate)
               (member ac-prefix ac-candidates))
      ;; Assume candidate is selected by just typing
      (setq ac-selected-candidate ac-prefix)
      (setq ac-last-point ac-point))
    (when ac-selected-candidate
      (ac-comphist-add ac-comphist
                       ac-selected-candidate
                       (if ac-last-point
                           (- ac-last-point ac-point)
                         (length ac-prefix)))))
  (ac-deactivate-completing-map)
  (ac-remove-prefix-overlay)
  (ac-remove-quick-help)
  (ac-inline-delete)
  (ac-menu-delete)
  (ac-cancel-timer)
  (ac-cancel-show-menu-timer)
  (ac-cancel-quick-help-timer)
  (setq ac-cursor-color nil
        ac-inline nil
        ac-show-menu nil
        ac-menu nil
        ac-completing nil
        ac-point nil
        ac-last-point nil
        ac-prefix nil
        ac-prefix-overlay nil
        ac-selected-candidate nil
        ac-common-part nil
        ac-whole-common-part nil
        ac-triggered nil
        ac-limit nil
        ac-candidates nil
        ac-candidates-cache nil
        ac-fuzzy-enable nil
        ac-dwim-enable nil
        ac-compiled-sources nil
        ac-current-sources nil
        ac-current-prefix-def nil
        ac-ignoring-prefix-def nil))

(defsubst ac-abort ()
  "Abort completion."
  (ac-cleanup))

(defun ac-expand-string (string &optional remove-undo-boundary)
  "Expand `STRING' into the buffer and update `ac-prefix' to `STRING'.
This function records deletion and insertion sequences by `undo-boundary'.
If `remove-undo-boundary' is non-nil, this function also removes `undo-boundary'
that have been made before in this function."
  (when (not (equal string (buffer-substring ac-point (point))))
    (undo-boundary)
    ;; We can't use primitive-undo since it undoes by
    ;; groups, divided by boundaries.
    ;; We don't want boundary between deletion and insertion.
    ;; So do it manually.
    ;; Delete region silently for undo:
    (if remove-undo-boundary
        (progn
          (let (buffer-undo-list)
            (save-excursion
              (delete-region ac-point (point))))
          (setq buffer-undo-list
                (nthcdr 2 buffer-undo-list)))
      (delete-region ac-point (point)))
    (insert string)
    ;; Sometimes, possible when omni-completion used, (insert) added
    ;; to buffer-undo-list strange record about position changes.
    ;; Delete it here:
    (when (and remove-undo-boundary
               (integerp (cadr buffer-undo-list)))
      (setcdr buffer-undo-list (nthcdr 2 buffer-undo-list)))
    (undo-boundary)
    (setq ac-selected-candidate string)
    (setq ac-prefix string)))

(defun ac-set-trigger-key (key)
  "Set `ac-trigger-key' to `KEY'. It is recommemded to use this function instead of calling `setq'."
  ;; Remove old mapping
  (when ac-trigger-key
    (define-key ac-mode-map (read-kbd-macro ac-trigger-key) nil))

  ;; Make new mapping
  (setq ac-trigger-key key)
  (when key
    (define-key ac-mode-map (read-kbd-macro key) 'ac-trigger-key-command)))

(defun ac-set-timer ()
  (unless ac-timer
    (setq ac-timer (run-with-idle-timer ac-delay ac-delay 'ac-update-greedy))))

(defun ac-cancel-timer ()
  (when (timerp ac-timer)
    (cancel-timer ac-timer)
    (setq ac-timer nil)))

(defun ac-update (&optional force)
  (when (and auto-complete-mode
             ac-prefix
             (or ac-triggered
                 force)
             (not isearch-mode))
    (ac-put-prefix-overlay)
    (setq ac-candidates (ac-candidates))
    (let ((preferred-width (popup-preferred-width ac-candidates)))
      ;; Reposition if needed
      (when (or (null ac-menu)
                (>= (popup-width ac-menu) preferred-width)
                (<= (popup-width ac-menu) (- preferred-width 10))
                (and (> (popup-direction ac-menu) 0)
                     (ac-menu-at-wrapper-line-p)))
        (ac-inline-hide) ; Hide overlay to calculate correct column
        (ac-menu-delete)
        (ac-menu-create ac-point preferred-width ac-menu-height)))
    (ac-update-candidates 0 0)
    t))

(defun ac-update-greedy (&optional force)
  (let (result)
    (while (when (and (setq result (ac-update force))
                      (null ac-candidates))
             (add-to-list 'ac-ignoring-prefix-def ac-current-prefix-def)
             (ac-start :force-init t)
             ac-current-prefix-def))
    result))

(defun ac-set-show-menu-timer ()
  (when (and (or (integerp ac-auto-show-menu) (floatp ac-auto-show-menu))
             (null ac-show-menu-timer))
    (setq ac-show-menu-timer (run-with-idle-timer ac-auto-show-menu ac-auto-show-menu 'ac-show-menu))))

(defun ac-cancel-show-menu-timer ()
  (when (timerp ac-show-menu-timer)
    (cancel-timer ac-show-menu-timer)
    (setq ac-show-menu-timer nil)))

(defun ac-show-menu ()
  (when (not (eq ac-show-menu t))
    (setq ac-show-menu t)
    (ac-inline-hide)
    (ac-remove-quick-help)
    (ac-update t)))

(defun ac-help (&optional persist)
  (interactive "P")
  (when ac-menu
    (popup-menu-show-help ac-menu persist)))

(defun ac-persist-help ()
  (interactive)
  (ac-help t))

(defun ac-last-help (&optional persist)
  (interactive "P")
  (when ac-last-completion
    (popup-item-show-help (cdr ac-last-completion) persist)))

(defun ac-last-persist-help ()
  (interactive)
  (ac-last-help t))

(defun ac-set-quick-help-timer ()
  (when (and ac-use-quick-help
             (null ac-quick-help-timer))
    (setq ac-quick-help-timer (run-with-idle-timer ac-quick-help-delay ac-quick-help-delay 'ac-quick-help))))

(defun ac-cancel-quick-help-timer ()
  (when (timerp ac-quick-help-timer)
    (cancel-timer ac-quick-help-timer)
    (setq ac-quick-help-timer nil)))

(defun ac-pos-tip-show-quick-help (menu &optional item &rest args)
  (let* ((point (plist-get args :point))
         (around nil)
         (parent-offset (popup-offset menu))
         (doc (popup-menu-documentation menu item)))
    (when (stringp doc)
      (if (popup-hidden-p menu)
          (setq around t)
        (setq point nil))
      (with-no-warnings
        (pos-tip-show doc
                      'popup-tip-face
                      (or point
                          (and menu
                               (popup-child-point menu parent-offset))
                          (point))
                      nil 0
                      popup-tip-max-width
                      nil nil
                      (and (not around) 0))
        (unless (plist-get args :nowait)
          (clear-this-command-keys)
          (unwind-protect
              (push (read-event (plist-get args :prompt)) unread-command-events)
            (pos-tip-hide))
          t)))))

(defun ac-quick-help (&optional force)
  (interactive)
  (when (and (or force (null this-command))
             (ac-menu-live-p)
             (null ac-quick-help))
      (setq ac-quick-help
            (funcall (if (and ac-quick-help-prefer-x
                              (eq window-system 'x)
                              (featurep 'pos-tip))
                         'ac-pos-tip-show-quick-help
                       'popup-menu-show-quick-help)
                     ac-menu nil
                     :point ac-point
                     :height ac-quick-help-height
                     :nowait t))))

(defun ac-remove-quick-help ()
  (when ac-quick-help
    (popup-delete ac-quick-help)
    (setq ac-quick-help nil)))

(defun ac-last-quick-help ()
  (interactive)
  (when (and ac-last-completion
             (eq (marker-buffer (car ac-last-completion))
                 (current-buffer)))
    (let ((doc (popup-item-documentation (cdr ac-last-completion)))
          (point (marker-position (car ac-last-completion))))
      (when (stringp doc)
        (if (and ac-quick-help-prefer-x
                 (eq window-system 'x)
                 (featurep 'pos-tip))
            (with-no-warnings (pos-tip-show doc nil point nil 0))
          (popup-tip doc
                     :point point
                     :around t
                     :scroll-bar t
                     :margin t))))))

(defmacro ac-define-quick-help-command (name arglist &rest body)
  (declare (indent 2))
  `(progn
     (defun ,name ,arglist ,@body)
     (put ',name 'ac-quick-help-command t)))

(ac-define-quick-help-command ac-quick-help-scroll-down ()
  (interactive)
  (when ac-quick-help
    (popup-scroll-down ac-quick-help)))

(ac-define-quick-help-command ac-quick-help-scroll-up ()
  (interactive)
  (when ac-quick-help
    (popup-scroll-up ac-quick-help)))



;;;; Auto completion isearch

(defun ac-isearch-callback (list)
  (setq ac-dwim-enable (eq (length list) 1)))

(defun ac-isearch ()
  (interactive)
  (when (ac-menu-live-p)
    (ac-cancel-show-menu-timer)
    (ac-cancel-quick-help-timer)
    (ac-show-menu)
    (popup-isearch ac-menu :callback 'ac-isearch-callback)))



;;;; Auto completion commands

(defun auto-complete (&optional sources)
  "Start auto-completion at current point."
  (interactive)
  (let ((menu-live (ac-menu-live-p))
        (inline-live (ac-inline-live-p)))
    (ac-abort)
    (let ((ac-sources (or sources ac-sources)))
      (if (or ac-show-menu-immediately-on-auto-complete
              inline-live)
          (setq ac-show-menu t))
      (ac-start))
    (when (ac-update-greedy t)
      ;; TODO Not to cause inline completion to be disrupted.
      (if (ac-inline-live-p)
          (ac-inline-hide))
      ;; Not to expand when it is first time to complete
      (when (and (or (and (not ac-expand-on-auto-complete)
                          (> (length ac-candidates) 1)
                          (not menu-live))
                     (not (let ((ac-common-part ac-whole-common-part))
                            (ac-expand-common))))
                 ac-use-fuzzy
                 (null ac-candidates))
        (ac-fuzzy-complete)))))

(defun ac-fuzzy-complete ()
  "Start fuzzy completion at current point."
  (interactive)
  (when (require 'fuzzy nil)
    (unless (ac-menu-live-p)
      (ac-start))
    (let ((ac-match-function 'fuzzy-all-completions))
      (unless ac-cursor-color
        (setq ac-cursor-color (frame-parameter (selected-frame) 'cursor-color)))
      (if ac-fuzzy-cursor-color
          (set-cursor-color ac-fuzzy-cursor-color))
      (setq ac-show-menu t)
      (setq ac-fuzzy-enable t)
      (setq ac-triggered nil)
      (ac-update t)))
  t)

(defun ac-next ()
  "Select next candidate."
  (interactive)
  (when (ac-menu-live-p)
    (popup-next ac-menu)
    (setq ac-show-menu t)
    (if (eq this-command 'ac-next)
        (setq ac-dwim-enable t))))

(defun ac-previous ()
  "Select previous candidate."
  (interactive)
  (when (ac-menu-live-p)
    (popup-previous ac-menu)
    (setq ac-show-menu t)
    (if (eq this-command 'ac-previous)
        (setq ac-dwim-enable t))))

(defun ac-expand ()
  "Try expand, and if expanded twice, select next candidate."
  (interactive)
  (unless (ac-expand-common)
    (let ((string (ac-selected-candidate)))
      (when string
        (when (equal ac-prefix string)
          (ac-next)
          (setq string (ac-selected-candidate)))
        (ac-expand-string string (eq last-command this-command))
        ;; Do reposition if menu at long line
        (if (and (> (popup-direction ac-menu) 0)
                 (ac-menu-at-wrapper-line-p))
            (ac-reposition))
        (setq ac-show-menu t)
        string))))

(defun ac-expand-common ()
  "Try to expand meaningful common part."
  (interactive)
  (if (and ac-dwim ac-dwim-enable)
      (ac-complete)
    (when (and (ac-inline-live-p)
               ac-common-part)
      (ac-inline-hide) 
      (ac-expand-string ac-common-part (eq last-command this-command))
      (setq ac-common-part nil)
      t)))

(defun ac-complete ()
  "Try complete."
  (interactive)
  (let* ((candidate (ac-selected-candidate))
         (action (popup-item-property candidate 'action))
         (fallback nil))
    (when candidate
      (unless (ac-expand-string candidate)
        (setq fallback t))
      ;; Remember to show help later
      (when (and ac-point candidate)
        (unless ac-last-completion
          (setq ac-last-completion (cons (make-marker) nil)))
        (set-marker (car ac-last-completion) ac-point ac-buffer)
        (setcdr ac-last-completion candidate)))
    (ac-abort)
    (cond
     (action
      (funcall action))
     (fallback
      (ac-fallback-command)))
    candidate))

(defun* ac-start (&key
                  requires
                  force-init)
  "Start completion."
  (interactive)
  (if (not auto-complete-mode)
      (message "auto-complete-mode is not enabled")
    (let* ((info (ac-prefix requires ac-ignoring-prefix-def))
           (prefix-def (nth 0 info))
           (point (nth 1 info))
           (sources (nth 2 info))
           prefix
           (init (or force-init (not (eq ac-point point)))))
      (if (or (null point)
              (member (setq prefix (buffer-substring-no-properties point (point)))
                      ac-ignores))
          (prog1 nil
            (ac-abort))
        (unless ac-cursor-color
          (setq ac-cursor-color (frame-parameter (selected-frame) 'cursor-color)))
        (setq ac-show-menu (or ac-show-menu (if (eq ac-auto-show-menu t) t))
              ac-current-sources sources
              ac-buffer (current-buffer)
              ac-point point
              ac-prefix prefix
              ac-limit ac-candidate-limit
              ac-triggered t
              ac-current-prefix-def prefix-def)
        (when (or init (null ac-prefix-overlay))
          (ac-init))
        (ac-set-timer)
        (ac-set-show-menu-timer)
        (ac-set-quick-help-timer)
        (ac-put-prefix-overlay)))))

(defun ac-stop ()
  "Stop completiong."
  (interactive)
  (setq ac-selected-candidate nil)
  (ac-abort))

(defun ac-trigger-key-command (&optional force)
  (interactive "P")
  (if (or force (ac-trigger-command-p last-command))
      (auto-complete)
    (ac-fallback-command 'ac-trigger-key-command)))



;;;; Basic cache facility

(defvar ac-clear-variables-every-minute-timer nil)
(defvar ac-clear-variables-after-save nil)
(defvar ac-clear-variables-every-minute nil)
(defvar ac-minutes-counter 0)

(defun ac-clear-variable-after-save (variable &optional pred)
  (add-to-list 'ac-clear-variables-after-save (cons variable pred)))

(defun ac-clear-variables-after-save ()
  (dolist (pair ac-clear-variables-after-save)
    (if (or (null (cdr pair))
            (funcall (cdr pair)))
        (set (car pair) nil))))

(defun ac-clear-variable-every-minutes (variable minutes)
  (add-to-list 'ac-clear-variables-every-minute (cons variable minutes)))

(defun ac-clear-variable-every-minute (variable)
  (ac-clear-variable-every-minutes variable 1))

(defun ac-clear-variable-every-10-minutes (variable)
  (ac-clear-variable-every-minutes variable 10))

(defun ac-clear-variables-every-minute ()
  (incf ac-minutes-counter)
  (dolist (pair ac-clear-variables-every-minute)
    (if (eq (% ac-minutes-counter (cdr pair)) 0)
        (set (car pair) nil))))



;;;; Auto complete mode

(defun ac-cursor-on-diable-face-p (&optional point)
  (memq (get-text-property (or point (point)) 'face) ac-disable-faces))

(defun ac-trigger-command-p (command)
  "Return non-nil if `COMMAND' is a trigger command."
  (and (symbolp command)
       (or (memq command ac-trigger-commands)
           (string-match "self-insert-command" (symbol-name command))
           (string-match "electric" (symbol-name command)))))

(defun ac-fallback-command (&optional except-command)
  (let* ((auto-complete-mode nil)
         (keys (this-command-keys-vector))
         (command (if keys (key-binding keys))))
    (when (and (commandp command)
               (not (eq command except-command)))
      (setq this-command command)
      (call-interactively command))))

(defun ac-compatible-package-command-p (command)
  "Return non-nil if `COMMAND' is compatible with auto-complete."
  (and (symbolp command)
       (string-match ac-compatible-packages-regexp (symbol-name command))))

(defun ac-handle-pre-command ()
  (condition-case var
      (if (or (setq ac-triggered (and (not ac-fuzzy-enable) ; ignore key storkes in fuzzy mode
                                      (or (eq this-command 'auto-complete) ; special case
                                          (ac-trigger-command-p this-command)
                                          (and ac-completing
                                               (memq this-command ac-trigger-commands-on-completing)))
                                      (not (ac-cursor-on-diable-face-p))))
              (ac-compatible-package-command-p this-command))
          (progn
            (if (or (not (symbolp this-command))
                    (not (get this-command 'ac-quick-help-command)))
                (ac-remove-quick-help))
            ;; Not to cause inline completion to be disrupted.
            (ac-inline-hide))
        (ac-abort))
    (error (ac-error var))))

(defun ac-handle-post-command ()
  (condition-case var
      (when (and ac-triggered
                 (or ac-auto-start
                     ac-completing)
                 (not isearch-mode))
        (setq ac-last-point (point))
        (ac-start :requires (unless ac-completing ac-auto-start))
        (ac-inline-update))
    (error (ac-error var))))

(defun ac-setup ()
  (if ac-trigger-key
      (ac-set-trigger-key ac-trigger-key))
  (if ac-use-comphist
      (ac-comphist-init))
  (unless ac-clear-variables-every-minute-timer
    (setq ac-clear-variables-every-minute-timer (run-with-timer 60 60 'ac-clear-variables-every-minute)))
  (if ac-stop-flymake-on-completing
      (defadvice flymake-on-timer-event (around ac-flymake-stop-advice activate)
        (unless ac-completing
          ad-do-it))
    (ad-disable-advice 'flymake-on-timer-event 'around 'ac-flymake-stop-advice)))

(define-minor-mode auto-complete-mode
  "AutoComplete mode"
  :lighter " AC"
  :keymap ac-mode-map
  :group 'auto-complete
  (if auto-complete-mode
      (progn
        (ac-setup)
        (add-hook 'pre-command-hook 'ac-handle-pre-command nil t)
        (add-hook 'post-command-hook 'ac-handle-post-command nil t)
        (add-hook 'after-save-hook 'ac-clear-variables-after-save nil t)
        (run-hooks 'auto-complete-mode-hook))
    (remove-hook 'pre-command-hook 'ac-handle-pre-command t)
    (remove-hook 'post-command-hook 'ac-handle-post-command t)
    (remove-hook 'after-save-hook 'ac-clear-variables-after-save t)
    (ac-abort)))

(defun auto-complete-mode-maybe ()
  "What buffer `auto-complete-mode' prefers."
  (if (and (not (minibufferp (current-buffer)))
           (memq major-mode ac-modes))
      (auto-complete-mode 1)))

(define-global-minor-mode global-auto-complete-mode
  auto-complete-mode auto-complete-mode-maybe
  :group 'auto-complete)



;;;; Compatibilities with other extensions

(defun ac-flyspell-workaround ()
  "Flyspell uses `sit-for' for delaying its process. Unfortunatelly,
it stops auto completion which is trigger with `run-with-idle-timer'.
This workaround avoid flyspell processes when auto completion is being started."
  (interactive)
  (defadvice flyspell-post-command-hook (around ac-flyspell-workaround activate)
    (unless ac-triggered
      ad-do-it)))



;;;; Standard sources

(defmacro ac-define-source (name source)
  "Source definition macro. It defines a complete command also."
  (declare (indent 1))
  `(progn
     (defvar ,(intern (format "ac-source-%s" name))
       ,source)
     (defun ,(intern (format "ac-complete-%s" name)) ()
       (interactive)
       (auto-complete '(,(intern (format "ac-source-%s" name)))))))

;; Words in buffer source
(defvar ac-word-index nil)

(defun ac-candidate-words-in-buffer (point prefix limit)
  (let ((i 0)
        candidate
        candidates
        (regexp (concat "\\_<" (regexp-quote prefix) "\\(\\sw\\|\\s_\\)+\\_>")))
    (save-excursion
      ;; Search backward
      (goto-char point)
      (while (and (or (not (integerp limit)) (< i limit))
                  (re-search-backward regexp nil t))
        (setq candidate (match-string-no-properties 0))
        (unless (member candidate candidates)
          (push candidate candidates)
          (incf i)))
      ;; Search backward
      (goto-char (+ point (length prefix)))
      (while (and (or (not (integerp limit)) (< i limit))
                  (re-search-forward regexp nil t))
        (setq candidate (match-string-no-properties 0))
        (unless (member candidate candidates)
          (push candidate candidates)
          (incf i)))
      (nreverse candidates))))

(defun ac-incremental-update-word-index ()
  (unless (local-variable-p 'ac-word-index)
    (make-local-variable 'ac-word-index))
  (if (null ac-word-index)
      (setq ac-word-index (cons nil nil)))
  ;; Mark incomplete
  (if (car ac-word-index)
      (setcar ac-word-index nil))
  (let ((index (cdr ac-word-index))
        (words (ac-candidate-words-in-buffer ac-point ac-prefix (or (and (integerp ac-limit) ac-limit) 10))))
    (dolist (word words)
      (unless (member word index)
        (push word index)
        (setcdr ac-word-index index)))))

(defun ac-update-word-index-1 ()
  (unless (local-variable-p 'ac-word-index)
    (make-local-variable 'ac-word-index))
  (when (and (not (car ac-word-index))
             (< (buffer-size) 1048576))
    ;; Complete index
    (setq ac-word-index
          (cons t
                (split-string (buffer-substring-no-properties (point-min) (point-max))
                              "\\(?:^\\|\\_>\\).*?\\(?:\\_<\\|$\\)")))))

(defun ac-update-word-index ()
  (dolist (buffer (buffer-list))
    (when (or ac-fuzzy-enable
              (not (eq buffer (current-buffer))))
      (with-current-buffer buffer
        (ac-update-word-index-1)))))

(defun ac-word-candidates (&optional buffer-pred)
  (loop initially (unless ac-fuzzy-enable (ac-incremental-update-word-index))
        for buffer in (buffer-list)
        if (and (or (not (integerp ac-limit)) (< (length candidates) ac-limit))
                (if buffer-pred (funcall buffer-pred buffer) t))
        append (funcall ac-match-function
                        ac-prefix
                        (and (local-variable-p 'ac-word-index buffer)
                             (cdr (buffer-local-value 'ac-word-index buffer))))
        into candidates
        finally return candidates))

(ac-define-source words-in-buffer
  '((candidates . ac-word-candidates)))

(ac-define-source words-in-all-buffer
  '((init . ac-update-word-index)
    (candidates . ac-word-candidates)))

(ac-define-source words-in-same-mode-buffers
  '((init . ac-update-word-index)
    (candidates . (ac-word-candidates
                   (lambda (buffer)
                     (derived-mode-p (buffer-local-value 'major-mode buffer)))))))

;; Lisp symbols source
(defvar ac-symbols-cache nil)
(ac-clear-variable-every-10-minutes 'ac-symbols-cache)

(defun ac-symbol-file (symbol type)
  (if (fboundp 'find-lisp-object-file-name)
      (find-lisp-object-file-name symbol type)
    (let ((file-name (with-no-warnings
                       (describe-simplify-lib-file-name
                        (symbol-file symbol type)))))
      (when (equal file-name "loaddefs.el")
        ;; Find the real def site of the preloaded object.
        (let ((location (condition-case nil
                            (if (eq type 'defun)
                                (find-function-search-for-symbol symbol nil
                                                                 "loaddefs.el")
                              (find-variable-noselect symbol file-name))
                          (error nil))))
          (when location
            (with-current-buffer (car location)
              (when (cdr location)
                (goto-char (cdr location)))
              (when (re-search-backward
                     "^;;; Generated autoloads from \\(.*\\)" nil t)
                (setq file-name (match-string 1)))))))
      (if (and (null file-name)
               (or (eq type 'defun)
                   (integerp (get symbol 'variable-documentation))))
          ;; It's a object not defined in Elisp but in C.
          (if (get-buffer " *DOC*")
              (if (eq type 'defun)
                  (help-C-file-name (symbol-function symbol) 'subr)
                (help-C-file-name symbol 'var))
            'C-source)
        file-name))))

(defun ac-symbol-documentation (symbol)
  (if (stringp symbol)
      (setq symbol (intern-soft symbol)))
  (ignore-errors
    (with-temp-buffer
      (let ((standard-output (current-buffer)))
        (prin1 symbol)
        (princ " is ")
        (cond
         ((fboundp symbol)
          (let ((help-xref-following t))
            (describe-function-1 symbol))
          (buffer-string))
         ((boundp symbol)
          (let ((file-name  (ac-symbol-file symbol 'defvar)))
            (princ "a variable")
            (when file-name
              (princ " defined in `")
              (princ (if (eq file-name 'C-source)
                         "C source code"
                       (file-name-nondirectory file-name))))
            (princ "'.\n\n")
            (princ (or (documentation-property symbol 'variable-documentation t)
                       "Not documented."))
            (buffer-string)))
         ((facep symbol)
          (let ((file-name  (ac-symbol-file symbol 'defface)))
            (princ "a face")
            (when file-name
              (princ " defined in `")
              (princ (if (eq file-name 'C-source)
                         "C source code"
                       (file-name-nondirectory file-name))))
            (princ "'.\n\n")
            (princ (or (documentation-property symbol 'face-documentation t)
                       "Not documented."))
            (buffer-string)))
         (t
          (let ((doc (documentation-property symbol 'group-documentation t)))
            (when doc
              (princ "a group.\n\n")
              (princ doc)
              (buffer-string)))))))))

(defun ac-symbol-candidates ()
  (or ac-symbols-cache
      (setq ac-symbols-cache
            (loop for x being the symbols
                  if (or (fboundp x)
                         (boundp x)
                         (symbol-plist x))
                  collect (symbol-name x)))))

(ac-define-source symbols
  '((candidates . ac-symbol-candidates)
    (document . ac-symbol-documentation)
    (symbol . "s")
    (cache)))

;; Lisp functions source
(defvar ac-functions-cache nil)
(ac-clear-variable-every-10-minutes 'ac-functions-cache)

(defun ac-function-candidates ()
  (or ac-functions-cache
      (setq ac-functions-cache
            (loop for x being the symbols
                  if (fboundp x)
                  collect (symbol-name x)))))

(ac-define-source functions
  '((candidates . ac-function-candidates)
    (document . ac-symbol-documentation)
    (symbol . "f")
    (prefix . "(\\(\\(?:\\sw\\|\\s_\\)+\\)")
    (cache)))

;; Lisp variables source
(defvar ac-variables-cache nil)
(ac-clear-variable-every-10-minutes 'ac-variables-cache)

(defun ac-variable-candidates ()
  (or ac-variables-cache
      (setq ac-variables-cache
            (loop for x being the symbols
                  if (boundp x)
                  collect (symbol-name x)))))

(ac-define-source variables
  '((candidates . ac-variable-candidates)
    (document . ac-symbol-documentation)
    (symbol . "v")
    (cache)))

;; Lisp features source
(defvar ac-emacs-lisp-features nil)
(ac-clear-variable-every-10-minutes 'ac-emacs-lisp-features)

(defun ac-emacs-lisp-feature-candidates ()
  (or ac-emacs-lisp-features
      (if (fboundp 'find-library-suffixes)
          (let ((suffix (concat (regexp-opt (find-library-suffixes) t) "\\'")))
            (setq ac-emacs-lisp-features
                  (append (mapcar 'prin1-to-string features)
                          (loop for dir in load-path
                                if (file-directory-p dir)
                                append (loop for file in (directory-files dir)
                                             if (string-match suffix file)
                                             collect (substring file 0 (match-beginning 0))))))))))

(ac-define-source features
  '((depends find-func)
    (candidates . ac-emacs-lisp-feature-candidates)
    (prefix . "require +'\\(\\(?:\\sw\\|\\s_\\)*\\)")
    (requires . 0)))

(defvaralias 'ac-source-emacs-lisp-features 'ac-source-features)

;; Abbrev source
(ac-define-source abbrev
  '((candidates . (mapcar 'popup-x-to-string (append (vconcat local-abbrev-table global-abbrev-table) nil)))
    (action . expand-abbrev)
    (symbol . "a")
    (cache)))

;; Files in current directory source
(ac-define-source files-in-current-dir
  '((candidates . (directory-files default-directory))
    (cache)))

;; Filename source
(defvar ac-filename-cache nil)

(defun ac-filename-candidate ()
  (unless (file-regular-p ac-prefix)
    (ignore-errors
      (loop with dir = (file-name-directory ac-prefix)
            with files = (or (assoc-default dir ac-filename-cache)
                             (let ((files (directory-files dir nil "^[^.]")))
                               (push (cons dir files) ac-filename-cache)
                               files))
            for file in files
            for path = (concat dir file)
            collect (if (file-directory-p path)
                        (concat path "/")
                      path)))))

(ac-define-source filename
  '((init . (setq ac-filename-cache nil))
    (candidates . ac-filename-candidate)
    (prefix . valid-file)
    (requires . 0)
    (action . ac-start)
    (limit . nil)))

;; Dictionary source
(defcustom ac-user-dictionary nil
  "User dictionary"
  :type '(repeat string)
  :group 'auto-complete)

(defcustom ac-user-dictionary-files '("~/.dict")
  "User dictionary files."
  :type '(repeat string)
  :group 'auto-complete)

(defcustom ac-dictionary-directories nil
  "Dictionary directories."
  :type '(repeat string)
  :group 'auto-complete)

(defvar ac-dictionary nil)
(defvar ac-dictionary-cache (make-hash-table :test 'equal))

(defun ac-clear-dictionary-cache ()
  (interactive)
  (clrhash ac-dictionary-cache))

(defun ac-read-file-dictionary (filename)
  (let ((cache (gethash filename ac-dictionary-cache 'none)))
    (if (and cache (not (eq cache 'none)))
        cache
      (let (result)
        (ignore-errors
          (with-temp-buffer
            (insert-file-contents filename)
            (setq result (split-string (buffer-string) "\n"))))
        (puthash filename result ac-dictionary-cache)
        result))))

(defun ac-buffer-dictionary ()
  (apply 'append
         (mapcar 'ac-read-file-dictionary
                 (mapcar (lambda (name)
                           (loop for dir in ac-dictionary-directories
                                 for file = (concat dir "/" name)
                                 if (file-exists-p file)
                                 return file))
                         (list (symbol-name major-mode)
                               (ignore-errors
                                 (file-name-extension (buffer-file-name))))))))

(defun ac-dictionary-candidates ()
  (apply 'append `(,ac-user-dictionary
                   ,(ac-buffer-dictionary)
                   ,@(mapcar 'ac-read-file-dictionary
                             ac-user-dictionary-files))))

(ac-define-source dictionary
  '((candidates . ac-dictionary-candidates)
    (symbol . "d")))

(provide 'auto-complete)
;;; auto-complete.el ends here


;;;; Additional sources

;; imenu

(defvar ac-imenu-index nil)

(ac-clear-variable-every-10-minutes 'ac-imenu-index)

(defun ac-imenu-candidates ()
  (loop with i = 0
        with stack = (progn
                       (unless (local-variable-p 'ac-imenu-index)
                         (make-local-variable 'ac-imenu-index))
                       (or ac-imenu-index
                           (setq ac-imenu-index
                                 (ignore-errors
                                   (with-no-warnings
                                     (imenu--make-index-alist))))))
        with result
        while (and stack (or (not (integerp ac-limit))
                             (< i ac-limit)))
        for node = (pop stack)
        if (consp node)
        do
        (let ((car (car node))
              (cdr (cdr node)))
          (if (consp cdr)
              (mapc (lambda (child)
                      (push child stack))
                    cdr)
            (when (and (stringp car)
                       (string-match (concat "^" (regexp-quote ac-prefix)) car))
              ;; Remove extra characters
              (if (string-match "^.*\\(()\\|=\\|<>\\)$" car)
                  (setq car (substring car 0 (match-beginning 1))))
              (push car result)
              (incf i))))
        finally return (nreverse result)))

(ac-define-source imenu
  '((depends imenu)
    (candidates . ac-imenu-candidates)
    (symbol . "s")))

;; gtags

(defface ac-gtags-candidate-face
  '((t (:background "lightgray" :foreground "navy")))
  "Face for gtags candidate"
  :group 'auto-complete)

(defface ac-gtags-selection-face
  '((t (:background "navy" :foreground "white")))
  "Face for the gtags selected candidate."
  :group 'auto-complete)

(defun ac-gtags-candidate ()
  (ignore-errors
    (split-string (shell-command-to-string (format "global -ci %s" ac-prefix)) "\n")))

(ac-define-source gtags
  '((candidates . ac-gtags-candidate)
    (candidate-face . ac-gtags-candidate-face)
    (selection-face . ac-gtags-selection-face)
    (requires . 3)
    (symbol . "s")))

;; yasnippet

(defface ac-yasnippet-candidate-face
  '((t (:background "sandybrown" :foreground "black")))
  "Face for yasnippet candidate."
  :group 'auto-complete)

(defface ac-yasnippet-selection-face
  '((t (:background "coral3" :foreground "white")))
  "Face for the yasnippet selected candidate."
  :group 'auto-complete)

(defun ac-yasnippet-table-hash (table)
  (cond
   ((fboundp 'yas/snippet-table-hash)
    (yas/snippet-table-hash table))
   ((fboundp 'yas/table-hash)
    (yas/table-hash table))))

(defun ac-yasnippet-table-parent (table)
  (cond
   ((fboundp 'yas/snippet-table-parent)
    (yas/snippet-table-parent table))
   ((fboundp 'yas/table-parent)
    (yas/table-parent table))))

(defun ac-yasnippet-candidate-1 (table)
  (with-no-warnings
    (let ((hashtab (ac-yasnippet-table-hash table))
          (parent (ac-yasnippet-table-parent table))
          candidates)
      (maphash (lambda (key value)
                 (push key candidates))
               hashtab)
      (setq candidates (all-completions ac-prefix (nreverse candidates)))
      (if parent
          (setq candidates
                (append candidates (ac-yasnippet-candidate-1 parent))))
      candidates)))

(defun ac-yasnippet-candidates ()
  (with-no-warnings
    (if (fboundp 'yas/get-snippet-tables)
        ;; >0.6.0
        (apply 'append (mapcar 'ac-yasnippet-candidate-1 (yas/get-snippet-tables major-mode)))
      (let ((table
             (if (fboundp 'yas/snippet-table)
                 ;; <0.6.0
                 (yas/snippet-table major-mode)
               ;; 0.6.0
               (yas/current-snippet-table))))
        (if table
            (ac-yasnippet-candidate-1 table))))))

(ac-define-source yasnippet
  '((depends yasnippet)
    (candidates . ac-yasnippet-candidates)
    (action . yas/expand)
    (candidate-face . ac-yasnippet-candidate-face)
    (selection-face . ac-yasnippet-selection-face)
    (symbol . "a")))

;; semantic

(defun ac-semantic-candidates (prefix)
  (with-no-warnings
    (delete ""            ; semantic sometimes returns an empty string
            (mapcar 'semantic-tag-name
                    (ignore-errors
                      (or (semantic-analyze-possible-completions
                           (semantic-analyze-current-context))
                          (senator-find-tag-for-completion prefix)))))))

(ac-define-source semantic
  '((available . (or (require 'semantic-ia nil t)
                     (require 'semantic/ia nil t)))
    (candidates . (ac-semantic-candidates ac-prefix))
    (prefix . c-dot-ref)
    (requires . 0)
    (symbol . "m")))

(ac-define-source semantic-raw
  '((available . (or (require 'semantic-ia nil t)
                     (require 'semantic/ia nil t)))
    (candidates . (ac-semantic-candidates ac-prefix))
    (symbol . "s")))

;; eclim

(defun ac-eclim-candidates ()
  (with-no-warnings
    (loop for c in (eclim/java-complete)
          collect (nth 1 c))))

(ac-define-source eclim
  '((candidates . ac-eclim-candidates)
    (prefix . c-dot)
    (requires . 0)
    (symbol . "f")))

;; css

;; Copied from company-css.el
(defconst ac-css-property-alist
  ;; see http://www.w3.org/TR/CSS21/propidx.html
  '(("azimuth" angle "left-side" "far-left" "left" "center-left" "center"
     "center-right" "right" "far-right" "right-side" "behind" "leftwards"
     "rightwards")
    ("background" background-color background-image background-repeat
     background-attachment background-position)
    ("background-attachment" "scroll" "fixed")
    ("background-color" color "transparent")
    ("background-image" uri "none")
    ("background-position" percentage length "left" "center" "right" percentage
     length "top" "center" "bottom" "left" "center" "right" "top" "center"
     "bottom")
    ("background-repeat" "repeat" "repeat-x" "repeat-y" "no-repeat")
    ("border" border-width border-style border-color)
    ("border-bottom" border)
    ("border-bottom-color" border-color)
    ("border-bottom-style" border-style)
    ("border-bottom-width" border-width)
    ("border-collapse" "collapse" "separate")
    ("border-color" color "transparent")
    ("border-left" border)
    ("border-left-color" border-color)
    ("border-left-style" border-style)
    ("border-left-width" border-width)
    ("border-right" border)
    ("border-right-color" border-color)
    ("border-right-style" border-style)
    ("border-right-width" border-width)
    ("border-spacing" length length)
    ("border-style" border-style)
    ("border-top" border)
    ("border-top-color" border-color)
    ("border-top-style" border-style)
    ("border-top-width" border-width)
    ("border-width" border-width)
    ("bottom" length percentage "auto")
    ("caption-side" "top" "bottom")
    ("clear" "none" "left" "right" "both")
    ("clip" shape "auto")
    ("color" color)
    ("content" "normal" "none" string uri counter "attr()" "open-quote"
     "close-quote" "no-open-quote" "no-close-quote")
    ("counter-increment" identifier integer "none")
    ("counter-reset" identifier integer "none")
    ("cue" cue-before cue-after)
    ("cue-after" uri "none")
    ("cue-before" uri "none")
    ("cursor" uri "*" "auto" "crosshair" "default" "pointer" "move" "e-resize"
     "ne-resize" "nw-resize" "n-resize" "se-resize" "sw-resize" "s-resize"
     "w-resize" "text" "wait" "help" "progress")
    ("direction" "ltr" "rtl")
    ("display" "inline" "block" "list-item" "run-in" "inline-block" "table"
     "inline-table" "table-row-group" "table-header-group" "table-footer-group"
     "table-row" "table-column-group" "table-column" "table-cell"
     "table-caption" "none")
    ("elevation" angle "below" "level" "above" "higher" "lower")
    ("empty-cells" "show" "hide")
    ("float" "left" "right" "none")
    ("font" font-style font-variant font-weight font-size "/" line-height
     font-family "caption" "icon" "menu" "message-box" "small-caption"
     "status-bar")
    ("font-family" family-name generic-family)
    ("font-size" absolute-size relative-size length percentage)
    ("font-style" "normal" "italic" "oblique")
    ("font-variant" "normal" "small-caps")
    ("font-weight" "normal" "bold" "bolder" "lighter" "100" "200" "300" "400"
     "500" "600" "700" "800" "900")
    ("height" length percentage "auto")
    ("left" length percentage "auto")
    ("letter-spacing" "normal" length)
    ("line-height" "normal" number length percentage)
    ("list-style" list-style-type list-style-position list-style-image)
    ("list-style-image" uri "none")
    ("list-style-position" "inside" "outside")
    ("list-style-type" "disc" "circle" "square" "decimal" "decimal-leading-zero"
     "lower-roman" "upper-roman" "lower-greek" "lower-latin" "upper-latin"
     "armenian" "georgian" "lower-alpha" "upper-alpha" "none")
    ("margin" margin-width)
    ("margin-bottom" margin-width)
    ("margin-left" margin-width)
    ("margin-right" margin-width)
    ("margin-top" margin-width)
    ("max-height" length percentage "none")
    ("max-width" length percentage "none")
    ("min-height" length percentage)
    ("min-width" length percentage)
    ("orphans" integer)
    ("outline" outline-color outline-style outline-width)
    ("outline-color" color "invert")
    ("outline-style" border-style)
    ("outline-width" border-width)
    ("overflow" "visible" "hidden" "scroll" "auto")
    ("padding" padding-width)
    ("padding-bottom" padding-width)
    ("padding-left" padding-width)
    ("padding-right" padding-width)
    ("padding-top" padding-width)
    ("page-break-after" "auto" "always" "avoid" "left" "right")
    ("page-break-before" "auto" "always" "avoid" "left" "right")
    ("page-break-inside" "avoid" "auto")
    ("pause" time percentage)
    ("pause-after" time percentage)
    ("pause-before" time percentage)
    ("pitch" frequency "x-low" "low" "medium" "high" "x-high")
    ("pitch-range" number)
    ("play-during" uri "mix" "repeat" "auto" "none")
    ("position" "static" "relative" "absolute" "fixed")
    ("quotes" string string "none")
    ("richness" number)
    ("right" length percentage "auto")
    ("speak" "normal" "none" "spell-out")
    ("speak-header" "once" "always")
    ("speak-numeral" "digits" "continuous")
    ("speak-punctuation" "code" "none")
    ("speech-rate" number "x-slow" "slow" "medium" "fast" "x-fast" "faster"
     "slower")
    ("stress" number)
    ("table-layout" "auto" "fixed")
    ("text-align" "left" "right" "center" "justify")
    ("text-decoration" "none" "underline" "overline" "line-through" "blink")
    ("text-indent" length percentage)
    ("text-transform" "capitalize" "uppercase" "lowercase" "none")
    ("top" length percentage "auto")
    ("unicode-bidi" "normal" "embed" "bidi-override")
    ("vertical-align" "baseline" "sub" "super" "top" "text-top" "middle"
     "bottom" "text-bottom" percentage length)
    ("visibility" "visible" "hidden" "collapse")
    ("voice-family" specific-voice generic-voice "*" specific-voice
     generic-voice)
    ("volume" number percentage "silent" "x-soft" "soft" "medium" "loud"
     "x-loud")
    ("white-space" "normal" "pre" "nowrap" "pre-wrap" "pre-line")
    ("widows" integer)
    ("width" length percentage "auto")
    ("word-spacing" "normal" length)
    ("z-index" "auto" integer))
  "A list of CSS properties and their possible values.")

(defconst ac-css-value-classes
  '((absolute-size "xx-small" "x-small" "small" "medium" "large" "x-large"
                   "xx-large")
    (border-style "none" "hidden" "dotted" "dashed" "solid" "double" "groove"
                  "ridge" "inset" "outset")
    (color "aqua" "black" "blue" "fuchsia" "gray" "green" "lime" "maroon" "navy"
           "olive" "orange" "purple" "red" "silver" "teal" "white" "yellow"
           "rgb")
    (counter "counter")
    (family-name "Courier" "Helvetica" "Times")
    (generic-family "serif" "sans-serif" "cursive" "fantasy" "monospace")
    (generic-voice "male" "female" "child")
    (margin-width "auto") ;; length percentage
    (relative-size "larger" "smaller")
    (shape "rect")
    (uri "url"))
  "A list of CSS property value classes and their contents.")

(defconst ac-css-pseudo-classes
  '("active" "after" "before" "first" "first-child" "first-letter" "first-line"
    "focus" "hover" "lang" "left" "link" "right" "visited")
  "Identifiers for CSS pseudo-elements and pseudo-classes.")

(defvar ac-css-property nil
  "Current editing property.")

(defun ac-css-prefix ()
  (when (save-excursion (re-search-backward "\\_<\\(.+?\\)\\_>\\s *:.*\\=" nil t))
    (setq ac-css-property (match-string 1))
    (or (ac-prefix-symbol) (point))))

(defun ac-css-property-candidates ()
  (or (loop with list = (assoc-default ac-css-property ac-css-property-alist)
            with seen = nil
            with value
            while (setq value (pop list))
            if (symbolp value)
            do (unless (memq value seen)
                 (push value seen)
                 (setq list
                       (append list
                               (or (assoc-default value ac-css-value-classes)
                                   (assoc-default (symbol-name value) ac-css-property-alist)))))
            else collect value)
      ac-css-pseudo-classes))

(defvar ac-source-css-property
  '((candidates . ac-css-property-candidates)
    (prefix . ac-css-prefix)
    (requires . 0)))



;;;; Not maintained sources

;; ropemacs

(defvar ac-ropemacs-loaded nil)
(defun ac-ropemacs-require ()
  (with-no-warnings
    (unless ac-ropemacs-loaded
      (pymacs-load "ropemacs" "rope-")
      (if (boundp 'ropemacs-enable-autoimport)
          (setq ropemacs-enable-autoimport t))
      (setq ac-ropemacs-loaded t))))

(defun ac-ropemacs-setup ()
  (ac-ropemacs-require)
  ;(setq ac-sources (append (list 'ac-source-ropemacs) ac-sources))
  (setq ac-omni-completion-sources '(("\\." ac-source-ropemacs))))

(defun ac-ropemacs-initialize ()
  (autoload 'pymacs-apply "pymacs")
  (autoload 'pymacs-call "pymacs")
  (autoload 'pymacs-eval "pymacs" nil t)
  (autoload 'pymacs-exec "pymacs" nil t)
  (autoload 'pymacs-load "pymacs" nil t)
  (add-hook 'python-mode-hook 'ac-ropemacs-setup)
  t)

(defvar ac-ropemacs-completions-cache nil)
(defvar ac-source-ropemacs
  '((init
     . (lambda ()
         (setq ac-ropemacs-completions-cache
               (mapcar
                (lambda (completion)
                  (concat ac-prefix completion))
                (ignore-errors
                  (rope-completions))))))
    (candidates . ac-ropemacs-completions-cache)))

;; rcodetools

(defvar ac-source-rcodetools
  '((init . (lambda ()
              (require 'rcodetools)
              (condition-case x
                  (save-excursion
                    (rct-exec-and-eval rct-complete-command-name "--completion-emacs-icicles"))
                (error) (setq rct-method-completion-table nil))))
    (candidates . (lambda ()
                    (all-completions
                     ac-prefix
                     (mapcar
                      (lambda (completion)
                        (replace-regexp-in-string "\t.*$" "" (car completion)))
                      rct-method-completion-table))))))



;;;; Default settings

(defun ac-common-setup ()
  (add-to-list 'ac-sources 'ac-source-filename))

(defun ac-emacs-lisp-mode-setup ()
  (setq ac-sources (append '(ac-source-features ac-source-functions ac-source-yasnippet ac-source-variables ac-source-symbols) ac-sources)))

(defun ac-cc-mode-setup ()
  (setq ac-sources (append '(ac-source-yasnippet ac-source-gtags) ac-sources)))

(defun ac-ruby-mode-setup ()
  (make-local-variable 'ac-ignores)
  (add-to-list 'ac-ignores "end"))

(defun ac-css-mode-setup ()
  (setq ac-sources (append '(ac-source-css-property) ac-sources)))

(defun ac-config-default ()
  (setq-default ac-sources '(ac-source-abbrev ac-source-dictionary ac-source-words-in-same-mode-buffers))
  (add-hook 'emacs-lisp-mode-hook 'ac-emacs-lisp-mode-setup)
  (add-hook 'c-mode-common-hook 'ac-cc-mode-setup)
  (add-hook 'ruby-mode-hook 'ac-ruby-mode-setup)
  (add-hook 'css-mode-hook 'ac-css-mode-setup)
  (add-hook 'auto-complete-mode-hook 'ac-common-setup)
  (global-auto-complete-mode t))

(provide 'auto-complete-config)
;;; auto-complete-config.el ends here

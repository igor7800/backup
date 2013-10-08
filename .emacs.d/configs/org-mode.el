;; Org Mode
(add-hook 'org-mode-hook
          (lambda ()
	    ;(org-indent-mode t)
	    (visual-line-mode t)
	    ;; Løs tab
	    (defun yas/org-very-safe-expand ()
	      (let ((yas/fallback-behavior 'return-nil)) (yas/expand)))
	    (make-variable-buffer-local 'yas/trigger-key)
	    (setq yas/trigger-key [tab])
	    (add-to-list 'org-tab-first-hook 'yas/org-very-safe-expand)
	    (define-key yas/keymap [tab] 'yas/next-field)
	    t))

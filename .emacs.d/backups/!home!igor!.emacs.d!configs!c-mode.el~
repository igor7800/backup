; C mode
(add-hook 'c-mode-common-hook
          (lambda()
            (require 'google-c-style)
            (google-make-newline-indent)
	    (google-set-c-style)
	    (local-set-key (kbd "ESC M-s") 'hs-show-block)
            (local-set-key (kbd "ESC M-h")  'hs-hide-block)
            (local-set-key (kbd "C-c C-<Up>")    'Hs-hide-all)
            (local-set-key (kbd "C-c C-<down>")  'hs-show-all)
            (hs-minor-mode t)
            ))
  

; flyspell 
(setq-default ispell-program-name "ispell")
(add-hook 'text-mode-hook 'british-flyspell)
(setq ispell-dictionary "british") 
(add-hook 'text-mode-hook 'flyspell-mode)
(add-hook 'text-mode-hook 'flyspell-buffer)
					
;spelling check
(global-set-key (kbd "ESC M-u") 'ispell-word)
(global-set-key (kbd "ESC M-y") 'ispell)


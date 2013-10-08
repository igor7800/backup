(setq initial-scratch-message nil)
;(server-start)

;; Auto-revert-mode -- når man har mange versioner af filer
(global-auto-revert-mode t)

(modify-frame-parameters nil '((wait-for-wm . nil)))


;; Vis paranteser der hører sammen
(show-paren-mode 1)
(setq show-paren-style 'parenthesis)
(setq show-paren-ring-bell-on-mismatch t)

;; Smart switch funktion
(ido-mode t)

;; Brug fælles clipboard
(setq x-select-enable-clipboard t)

;; Lav ikke backup filer
;(setq make-backup-files nil) 
(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))

;; Brug C-d, DELETE og BACKSLASH til at slette markeret tekst
(delete-selection-mode t)

;; Kolonner i statuslinjen
(setq column-number-mode t)

;; Set browser
(setq browse-url-browser-function 'browse-url-generic
      browse-url-generic-program "w3m")

;; "y or n" instead of "yes or no"
(fset 'yes-or-no-p 'y-or-n-p)


;Do not fucking beep! 
(setq visible-bell t)


; Make new frames fullscreen by default. Note: this hook doesn't do
; anything to the initial frame if it's in your .emacs, since that file is
; read _after_ the initial frame is created.
;(add-hook 'after-make-frame-functions 'toggle-fullscreen)


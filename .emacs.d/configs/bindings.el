;; F3 i minibuffer: Indsæt filnavn
(define-key minibuffer-local-map [f3]
  (lambda() (interactive) (insert (buffer-file-name (nth 1 (buffer-list))))))

;; Desktop mode - Gem skriveborde
(global-set-key (kbd "C-c s") 'my-desktop-save)
(global-set-key (kbd "C-c f") 'my-desktop-read)


;; Sæt C-Tab til tab-through-buffers
(global-set-key (kbd "<C-tab>") 'tabbar-forward)
(global-set-key (kbd "<C-S-iso-lefttab>") 'tabbar-backward)

(global-set-key [f11] 'toggle-fullscreen)

;; Brug Ibuffer som buffermanager
(global-set-key (kbd "C-x C-b") 'ibuffer)
(setq ibuffer-show-empty-filter-groups nil)


(setq ibuffer-saved-filter-groups
      '(("default"
          ("Emacs conf" (or
                       (filename . "/home/denhart/.emacs*")
		      ))
         ("AAU - Project 2" (or
                             (filename . "/home/denhart/Documents/AAU/project2/*")
                             ))
         ("Agenda" (or (name . "^\\*Calendar\\*$")
                       (name . "^diary$")
                       (name . "^\\*Agenda")
                       (name . "^\\*org-")
                       (name . "^\\*Org")
                       (mode . org-mode)
                       (mode . muse-mode)))
         ("dired" (or (mode . dired-mode))))))

(add-hook 'ibuffer-mode-hook
          (lambda ()
            (ibuffer-switch-to-saved-filter-groups "default")))


    ;; (setq ibuffer-saved-filter-groups
    ;;       (quote (("default"
    ;;                ("planner" (or
    ;;                            (name . "^\\*Calendar\\*$")
    ;;                            (name . "^diary$")
    ;;                            (mode . muse-mode)))
    ;;                ("emacs" (or
    ;;                          (name . "^\\*scratch\\*$")
    ;;                          (name . "^\\*Messages\\*$")))
    ;;                ("AAU - Project 2" (or
    ;;                         (filename . "~/Documents/AAU/project2")))))))

    ;; (add-hook 'ibuffer-mode-hook
    ;;           (lambda ()
    ;;             (ibuffer-switch-to-saved-filter-groups "default")))


;;Remap macro play 
(global-set-key '[(shift f5)]    'call-last-kbd-macro)
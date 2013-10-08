;; ePix-snipplets
;(setq load-path (cons "~/share/emacs/" load-path))
(setq auto-mode-alist (cons '("\\.xp" . epix-mode) auto-mode-alist))
(autoload 'epix-mode "epix" "ePiX editing mode" t)
(setq epix-mark-files-as-epix t)
(setq epix-insert-template-in-empty-buffer t)

(autoload 'flix-mode "epix" "ePiX editing mode" t)
(setq auto-mode-alist (cons '("\\.flx" . flix-mode) auto-mode-alist))

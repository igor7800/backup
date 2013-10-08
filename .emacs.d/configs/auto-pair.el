;Autopair
(require 'autopair)
(autopair-global-mode 1) 
(setq autopair-autowrap t)

;(add-hook 'c-mode-common-hook
;	  #'(lambda ()
;	      (setq autopair-dont-activate t)
;	      (autopair-mode -1)))
;
;(add-hook 'c++-mode-hook
;	  #'(lambda ()
;	      (setq autopair-dont-activate t)
;	      (autopair-mode -1)))
;
;(add-hook 'c++-mode-hook
;	  #'(lambda ()
;	      (push '(?< . ?>)
;		    (getf autopair-extra-pairs :code))))


;; Closing brackets using electric-pair defun, in c-mode 
					;(add-hook 'c-mode-hook
					;  (lambda ()
					;   (define-key c-mode-map "(" 'electric-pair)
					;  (define-key c-mode-map "[" 'electric-pair)
					;    (define-key c-mode-map "{" 'electric-pair)
					;   ))

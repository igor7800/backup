;; LaTeX mode
(require 'tex-site)
(add-hook 'LaTeX-mode-hook 
	  (lambda ()
	    (latex-math-mode t)
	    (visual-line-mode t)
	    (outline-minor-mode t)
	    (orgtbl-mode t)
	    (reftex-mode t)
	    (setq-default ispell-local-dictionary "danish")
	    (flyspell-mode t)
	    (flyspell-buffer) 
	    (setq reftex-plug-into-AUCTeX t)
	    ;(tex-fold-mode t)
	    (local-set-key [f9] 'preview-function)
	    (local-set-key [f8] 'unpreview-function)
	    (load "preview-latex.el" nil t t)
	    (load "auctex.el" nil t t)
	    (tex-pdf-mode t)
	    (setq-default TeX-master nil)
	    ))

;; ebib
(autoload 'ebib "ebib" "Ebib, a BibTeX database manager." t)

	    
	    






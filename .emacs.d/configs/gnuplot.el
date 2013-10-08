;;Gnuplot
(autoload 'gnuplot-mode "vendor/gnuplot" "gnuplot major mode" t)
(autoload 'gnuplot-make-buffer "vendor/gnuplot" "open a buffer in gnuplot-mode" t)
(setq auto-mode-alist (append '(("\\.gp$" . gnuplot-mode))
			      auto-mode-alist))

;Color theme
(require 'color-theme)
(color-theme-initialize)



;(setq color-theme-is-global t)
;(color-theme-lawrence)
;(color-theme-euphoria)
;(color-theme-sitaramv-nt)
;(color-theme-digital-ofs1)
;(color-theme-greiner)
;(color-theme-solarized-dark)
;(color-theme-xoria256)
;(color-theme-goldenrod)
(color-theme-jsc-light)




(add-to-list 'default-frame-alist'(background-color . "black"))
(add-to-list 'default-frame-alist'(foreground-color . "white"))
(set-face-foreground 'mode-line "black")
(set-face-background 'mode-line "white")
(set-face-background 'mode-line-buffer-id "blue")
(set-face-foreground 'mode-line-buffer-id "black")
    

; Menu-bar
(menu-bar-mode -1)

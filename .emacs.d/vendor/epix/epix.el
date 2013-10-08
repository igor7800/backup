;;; epix.el --- A major mode for working with ePiX files.

;; Copyright (C) 2002, 2007 Jay Belanger

;; Author: Jay Belanger
;; Maintainer: Jay Belanger <belanger@truman.edu>

;; Keywords: epix

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.
;;          
;; This program is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
;; PURPOSE.  See the GNU General Public License for more details.
;;          
;; You should have received a copy of the GNU General Public
;; License along with this program; if not, write to the Free
;; Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
;; MA 02111-1307 USA
;;
;;
;; Please send suggestions and bug reports to <belanger@truman.edu>. 

;;; Commentary:

;; Quick intro

;; epix-mode is an extension of c++-mode with some extra commands for 
;; editing ePiX files.  The commands are
;;  C-cC-x    run epix on the current file (x for epiX, I guess)
;;  C-cC-l    run elaps on the current file (l for eLaps)
;; The output of the run can be seen by
;;  C-cC-r    show the output buffer  (r for Results)
;; and in case of errors, they can be jumped to, in sequence, with
;;  C-c`      go to the next error
;; The file created by elaps can be viewed with
;;  C-cC-v    view the output file  (v for View)
;; By default, the output will be encapsulated postscript.  This
;;  can be changed by changing the customizable variable
;;  `epix-elaps-output-format'.  This can be changed for the current
;;  emacs session with `C-cC-r'.
;; An unwanted ePiX process can be killed with
;;  C-cC-k
;; A reminder of some ePiX commands will be given with 
;;  C-cC-h    get help on ePiX
;; If the file extension is .flx, then there will also be the commands
;;  C-cC-f    run flix on the current file
;;  C-cC-w    view the mng file.
;;
;; To install, put both epix.el and epix.info in the emacs load path.
;; Adding the lines
;;   (autoload 'epix-mode "epix" "ePiX editing mode" t)
;;   (autoload 'flix-mode "epix" "flix editing mode" t)
;; to your .emacs file will ensure that the command is always available.
;; Adding the lines
;;   (setq auto-mode-alist (cons '("\\.xp" . epix-mode) auto-mode-alist))
;;   (setq auto-mode-alist (cons '("\\.flx" . flix-mode) auto-mode-alist))
;; will ensure that any file ending in .xp or .flx will be recognized as 
;; an ePiX file or flix file, and started in the proper mode.
;;
;; Some variables that the user may wish to change (via customization
;; or otherwise) are
;;  epix-postscript-viewer  (default "gv")
;;     The command used to view postscript files.
;;  epix-mng-viewer  (default "display")
;;     The command used to view mng files.
;;  epix-mark-files-as-epix (default nil)
;;     Setting this to t will ensure that any file in ePiX mode
;;     will be marked with a /* -*-ePiX-* */ so that next 
;;     time it is opened, it will be put in epix-mode.  (This isn't necessary 
;;     if auto-mode-alist is set up properly.)
;;  epix-mark-files-as-flix (default nil)
;;     Setting this to t will ensure that any file in flix mode
;;     will be marked with a /* -*-flix-* */ so that next 
;;     time it is opened, it will be put in flix-mode.  (This isn't necessary 
;;     if auto-mode-alist is set up properly.)
;;  epix-insert-template-in-empty-buffer (default nil)
;;     Setting this to t will cause any empty buffer which is put in
;;     ePiX mode to have a skeleton of commands inserted into it.
;;     The skeleton can be inserted at any time with the command
;;     epix-insert-template
;;  epix-template
;;     This is the skeleton which will inserted.
;;     By default, it is
;;       #include \"epix.h\"
;;       using namespace ePiX;
;;
;;       int main()
;;       {
;;         picture(P(,), P(,), \"\");
;;
;;         begin();
;;
;;         end();
;;       }
;;
;;  epix-flix-template
;;     This is the skeleton which will inserted.
;;     By default, it is
;;       #include \"epix.h\"
;;       using namespace ePiX;
;;
;;       int main(int argc, char* argv[])
;;       {
;;        if (argc == 3)
;;         {
;;          char* arg;
;;          double temp1, temp2;
;;          temp1=strtod(argv[1], &arg);
;;          temp2=strtod(argv[2], &arg);
;;
;;          tix()=temp1/temp2;
;;         }
;;         picture(P(,), P(,), \"\");
;;
;;         begin();
;;
;;         end();
;;       }

;;; Require
(require 'cc-mode)

;;; Customization

(defgroup epix nil
  "ePiX mode"
  :prefix "epix-"
  :tag    "ePiX")

(defcustom epix-elaps-output-format 'eps
  "The output format for elaps."
  :group 'epix
  :type '(choice (const :tag "EPS" eps)
                 (const :tag "PS" ps)
                 (const :tag "PDF" pdf)))

(defcustom epix-info-file "/usr/local/share/info/epix.info"
  "The info file for ePiX."
  :group 'epix
  :type 'file)

(defcustom epix-mark-files-as-epix nil
  "Non-nil means to make sure that any ePiX file is marked as such."
  :group 'epix
  :type 'boolean)

(defcustom epix-mark-files-as-flix nil
  "Non-nil means to make sure that any flix file is marked as such."
  :group 'epix
  :type 'boolean)

(defcustom epix-template 
"#include \"epix.h\"
using namespace ePiX;

int main()
{
picture(P(,), P(,), \"\");

begin();

end();
}
"
  "The information to enter into an empty ePiX buffer."
  :group 'epix
  :type 'string)

(defcustom epix-template-start "P("
  "The place to start the point in the template."
  :group 'epix
  :type 'string)

(defcustom epix-flix-template
"#include \"epix.h\"
using namespace ePiX;

int main(int argc, char* argv[])
{
  if (argc == 3)
    {
      char* arg;
      double temp1(strtod(argv[1], &arg)), temp2(strtod(argv[2], &arg));

      tix()=temp1/temp2;
    }
picture(P(,), P(,), \"\");

begin();

end();
}
"
  "The information to enter into an empty ePiX buffer."
  :group 'epix
  :type 'string)

(defcustom epix-flix-template-start "P("
  "The place to start the point in the template."
  :group 'epix
  :type 'string)

(defcustom epix-insert-template-in-empty-buffer nil
  "Non-nil means to insert the template into an empty ePiX buffer."
  :group 'epix
  :type 'boolean)

(defcustom epix-command-name "epix"
  "The name of the ePiX program."
  :group 'epix
  :type 'string)

(defcustom epix-command-args ""
  "Arguments to pass to epix"
  :group 'epix
  :type 'string)

(defcustom epix-elaps-command-name "elaps"
  "The name of the elaps program."
  :group 'epix
  :type 'string)

(defcustom epix-elaps-command-args ""
  "Arguments to pass to elaps"
  :group 'epix
  :type 'string)

(defcustom epix-flix-command-name "flix"
  "The name of the flix program."
  :group 'epix
  :type 'string)

(defcustom epix-flix-command-args ""
  "Arguments to pass to flix"
  :group 'epix
  :type 'string)

(defcustom epix-postscript-viewer "gv"
  "The name of the program used to view postscript files."
  :group 'epix
  :type 'string)

(defcustom epix-pdf-viewer "xpdf"
  "The name of the program used to view pdf files."
  :group 'epix
  :type 'string)

(defcustom epix-mng-viewer "display"
  "The name of the program used to view mng files."
  :group 'epix
  :type 'string)

;;; Some utility variables

(defvar epix-output-buffer nil)
(make-variable-buffer-local 'epix-output-buffer)

(defvar epix-error-point nil)
(make-variable-buffer-local 'epix-error-point)

(defvar epix-elaps-output-format-list
  '((ps " -ps" ".ps")
    (pdf " -pdf" ".pdf")
    (eps "" ".eps")))

(defun epix-change-elaps-output-format ()
  "Change the output format for elaps."
  (interactive)
  (let ((newformat
         (read-string 
          "New output format (ps,eps,pdf): ")))
    (cond
     ((string= newformat "pdf")
      (setq epix-elaps-output-format 'pdf))
     ((string= newformat "ps")
      (setq epix-elaps-output-format 'ps))
     ((string= newformat "eps")
      (setq epix-elaps-output-format 'eps))
     (t
      (message "Not an acceptable format.")))))

;;; Functions to run epix and friends

(defun epix-check-process ()
  "See if there is a process associated with the output buffer.
If there is and it is running, offer to kill it."
  (let ((epp)
        (epix-proc (get-buffer-process epix-output-buffer)))
    (if epix-proc (setq epp t) (setq epp nil))
    (if (and 
         epix-proc
         (y-or-n-p "There is an ePiX process running.  Kill it? "))
        (progn
          (kill-process epix-proc)
          (setq epp nil)))
    epp))

(defun epix-kill-process ()
  "Kill any epix process running."
  (interactive)
  (let ((epix-proc (get-buffer-process epix-output-buffer)))
    (if (and
         epix-proc
         (y-or-n-p "Really kill ePiX process? "))
        (kill-process epix-proc))))
         

(defun epix-check-buffer ()
  "See if the buffer has been modified since it was last saved.
If it has been, offer to save it."
  (if (and
       (buffer-modified-p)
       (y-or-n-p (concat "Save file " (buffer-file-name) "?")))
      (save-buffer)))

(defun epix-run-command (command file &optional args)
  "Create a process to run COMMAND on FILE.
Return the new process."
  (let ((buffer epix-output-buffer))
    (epix-check-buffer)
    (unless (epix-check-process)
      (set-buffer (get-buffer-create buffer))
      (setq epix-error-point nil)
      (erase-buffer)
      (insert "Running `" command "' on `" file "\n")
      (message "Type `C-c C-r' to display results of compilation.")
      (let ((process)
            (cmd))
        (if (not (string= args ""))
            (setq cmd 
                  (append 
                   (list 'start-process "ePiX" buffer "/bin/sh" command)
                   (split-string args)
                   (list file)))
          (setq cmd (list 'start-process "ePiX" buffer "/bin/sh" command file)))
        (setq process (eval cmd))
        (set-process-filter process 'epix-command-filter)
        (set-process-sentinel process 'epix-command-sentinel)
        (set-marker (process-mark process) (point-max))
        process))))
  
(defun epix-command-sentinel (process event)
  (when (string-match "finished" event)
    (message "ePiX process finished")
    (set-buffer epix-output-buffer)
    (goto-char (point-max))
    (insert "\nePiX process finished\n")))

(defun epix-command-filter (process string)
  "Filter to process normal output."
  (save-excursion
    (set-buffer (process-buffer process))
    (save-excursion
      (goto-char (process-mark process))
      (insert-before-markers string)
      (set-marker (process-mark process) (point))))
  (if (string-match "Compilation failed" string)
      (message (concat "ePiX errors in `" (buffer-name)
                       "'. Use C-c ` to display."))))
(defun epix-run-epix ()
  "Run epix on the current file."
  (interactive)
  (let ((file (file-name-nondirectory (buffer-file-name))))
    (epix-run-command epix-command-name file epix-command-args)))

(defun epix-run-elaps ()
  "Run elaps on the current file."
  (interactive)
  (let ((file (file-name-nondirectory (buffer-file-name))))
    (epix-run-command epix-elaps-command-name file 
                      (concat
                       epix-elaps-command-args
                       (nth 1 (assoc epix-elaps-output-format
                                     epix-elaps-output-format-list))))))

(defun epix-run-flix ()
  "Run flix on the current file."
  (interactive)
  (let ((file (file-name-nondirectory (buffer-file-name))))
    (epix-run-command epix-flix-command-name file epix-flix-command-args)))
  
(defun epix-view-elaps-output ()
  "View the eps output of the file."
  (interactive)
  (let ((filename (file-name-nondirectory (buffer-file-name)))
        (file nil)
        (extension (nth 2 (assoc epix-elaps-output-format
                                 epix-elaps-output-format-list))))
    (if (file-name-extension filename)
        (setq file (concat (file-name-sans-extension filename) extension)))
    (unless (file-exists-p file)
      (setq file (concat filename extension)))
    (message file)
    (if (file-exists-p file)
        (call-process 
         (if (eq epix-elaps-output-format 'pdf)
             epix-pdf-viewer
           epix-postscript-viewer)
         nil epix-output-buffer nil file)
      (message (concat "No file " file ".  Run elaps first.")))))

(defun epix-view-mng ()
  "View the mng output of the file."
  (interactive)
  (let ((filename (file-name-nondirectory (buffer-file-name)))
        (file nil))
    (if (file-name-extension filename)
        (setq file (concat (file-name-sans-extension filename) ".mng")))
    (unless (file-exists-p file)
      (setq file (concat filename ".mng")))
    (message file)
    (if (file-exists-p file)
        (call-process epix-mng-viewer nil epix-output-buffer nil file)
      (message (concat "No file " file ".  Run flix first.")))))

;;; Dealing with output

(defun epix-show-output-buffer ()
  "Show the epix output buffer."
  (interactive)
  (let ((buf (current-buffer)))
    (if (get-buffer epix-output-buffer)
        (progn
          (pop-to-buffer epix-output-buffer t)
          (bury-buffer buf)
	  (goto-char (point-max))
	  (recenter (/ (window-height) 2))
	  (pop-to-buffer buf))
      (message "No output buffer."))))

(defun epix-find-error (arg)
  "Go to the next ePiX error."
  (interactive "P")
  (if arg 
      (save-excursion
        (set-buffer epix-output-buffer)
        (setq epix-error-point nil)))
  (let ((ln)
        (col)
        (epix-error-end)
        (buf (current-buffer)))
    (switch-to-buffer-other-window epix-output-buffer)
    (widen)
    (if epix-error-point
        (goto-char epix-error-point)
      (goto-char (point-min)))
    (if (re-search-forward ":\\([0-9]+\\):\\([0-9]+\\):" (point-max) t)
        (progn
          (setq epix-error-point (point))
          (setq ln (string-to-int (match-string 1)))
          (setq col (string-to-int (match-string 2)))
          (save-excursion
            (if (re-search-forward ":[0-9]+:[0-9]+:" (point-max) t)
                (setq epix-error-end (line-beginning-position))
              (if (search-forward "Compilation failed" (point-max) t)
                  (setq epix-error-end (line-beginning-position))
                (setq epix-error-end (point-max)))))
          (recenter)
          (beginning-of-line)
          (if (looking-at "epix: Compiling...")
              (forward-char (length "epix: Compiling...")))
          (narrow-to-region (point) epix-error-end)
          (switch-to-buffer-other-window buf)
          (goto-line ln)
          (move-to-column col))
      (switch-to-buffer-other-window buf)
      (message "No more errors."))))


;;; Auxiliary functions

(defun epix-mark-file-as-epix ()
  "Mark the file as an ePiX buffer.
The next time the file is loaded, it will then be in ePiX mode"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at ".*-\\*-ePiX-\\*-")
      (insert "/* -*-ePiX-*- */\n"))))

(defun epix-mark-file-as-flix ()
  "Mark the file as a flix buffer.
The next time the file is loaded, it will then be in flix mode"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at ".*-\\*-flix-\\*-")
      (insert "/* -*-flix-*- */\n"))))

(defun epix-insert-epix-template ()
  "Insert a template."
  (interactive)
  (if (looking-at ".*-\\*-ePiX-\\*-")
      (forward-line 1))
  (let ((beg (point)))
    (insert epix-template)
    (indent-region beg (point) nil)
    (goto-char beg)
    (search-forward epix-template-start)))

(defun epix-insert-flix-template ()
  "Insert a template."
  (interactive)
  (if (looking-at ".*-\\*-flix-\\*-")
      (forward-line 1))
  (let ((beg (point)))
    (insert epix-flix-template)
    (indent-region beg (point) nil)
    (goto-char beg)
    (search-forward epix-flix-template-start)))

(defun epix-help ()
  "Read an ePiX info file"
  (interactive)
  (info-other-window epix-info-file))

(require 'info-look)
(info-lookup-maybe-add-help
 :mode 'epix-mode
 :ignore-case nil
 :regexp "[_a-zA-Z0-9./+-]+"
 :doc-spec (list
            (list
             (concat "("
                     epix-info-file
                     ")Function Index"))))
; nil
; "^ -+ [^:]+:[ ]+\\(\\[[^=]*=[ ]+\\)?" nil)))


;;; To take care of the different types

(defvar epix-preface
"int[ \t\n]*main()[ \t\n]*{")

(defvar epix-flix-preface
"int main(int argc, char* argv[])
{
  if (argc == 3)
    {
      char* arg;
      double temp1(strtod(argv[1], &arg)), temp2(strtod(argv[2], &arg));

      tix()=temp1/temp2;
    }")

(defun epix-epix-to-flix ()
  "Change some of the buffer to accomodate flix."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (replace-regexp "-\\*-ePiX-\\*-" "-*-flix-*-")
    (goto-char (point-min))
    (replace-regexp epix-preface epix-flix-preface))
  (flix-mode))

;;; ePiX mode

(defvar epix-mode-map nil
  "The keymap for ePiX mode.")

(if epix-mode-map
     nil
   (let ((map (copy-keymap c++-mode-map)))
     (define-key map "\C-c\C-k" 'epix-kill-process)
     (define-key map "\C-c\C-x" 'epix-run-epix)
     (define-key map "\C-c\C-l" 'epix-run-elaps)
     (define-key map "\C-c\C-r" 'epix-show-output-buffer)
     (define-key map "\C-c\C-v" 'epix-view-elaps-output)
     (define-key map "\C-c\C-r" 'epix-change-elaps-output-format)
     (define-key map "\C-c\C-h" 'epix-help)
     (define-key map "\C-c\C-i" 'info-complete-symbol)
     (define-key map "\C-c`" 'epix-find-error)
     (setq epix-mode-map map)))

(easy-menu-define epix-mode-menu epix-mode-map
  "ePiX mode menu"
  '("ePiX"
    ["Run ePiX" epix-run-epix t]
    ["Run elaps" epix-run-elaps t]
    ["View the eps file" epix-view-elaps-output t]
    ["Change the output format" epix-change-elaps-output-format t]
    ["Get help on ePiX" epix-help t]
    ["Show the output buffer" epix-show-output-buffer t]))

(define-derived-mode epix-mode c++-mode "ePiX"
  "ePiX mode is a major mode for editing ePiX files.
It is C++ mode with a couple of extra commands:

Run epix on the file being visited:   C-cC-x
Run elaps on the file being visited:  C-cC-l
View the output:                      C-cC-v
Change the output format:             C-cC-r
Get help on ePiX:                     C-cC-h
Complete the ePiX symbol under point: C-cTAB

In the case of errors:
Go to the (next) error:               C-c`

SUMMARY OF EPIX COMMANDS
------------------------

Preamble
--------
picture(P(a,b), P(c,d), \"height[dim] x width dim\");

The actual picture commands need to be between
begin();
and
end();

Colors
------
RGB(r,g,b);
Red(d);    Green(d);    Blue(d);    Black(d);      White(d);

CMY(c,m,y);
Cyan(d);   Magenta(d);  Yellow(d);  CMY_Black(d);  CMY_White(d);

CMYK(c,m,y,k);
CyanK(d);  MagentaK(d); YellowK(d); CMYK_Black(d); CMYK_White(d);

Primary densities interpolate linearly between anti-saturation (-1),
no color(0), full saturation (1), and saturation on all channels (2 
or -2). Densities are meaningful mod 4. Colors can be superposed, 
blended, inverted, filtered, and scaled.

Line and fill styles
-----------
Widths:  plain([Color]); bold([Color]); bbold([Color]);
         pen(Color, [len]);  pen(len);
         base(Color, [len]); base(len);
Styles:  solid(); dashed(); dotted();
         line_style(string);
Fill:    fill(Color); fill(bool); nofill();

The base pen draws an underlayer/border if wider than the line pen.
line_style accepts a WYSIWYG pattern of spaces, dashes, and periods.

Lines
-----
line(P(a,b),P(c,d));
Line(P(a,b),P(c,d));
Line(P(a,b),m);

The line goes from one point to the other,
the Line is that part of the entire line which lies inside the
bounding box.

Polygons
--------
triangle(P(a,b),P(c,d),P(e,f));
rect(P(a,b),P(c,d));
quad(P(a,b),P(c,d),P(e,f),P(g,h));

Axes
----
h_axis(P(a,b),P(c,d),n);
v_axis(P(a,b),P(c,d),n);
h_log_axis(P(a,b),P(c,d),n);
v_log_axis(P(a,b),P(c,d),n);

h_axis_labels(P(a,b),P(c,d),n,P(u,v));
v_axis_labels(P(a,b),P(c,d),n,P(u,v));
h_log_axis_labels(P(a,b),P(c,d),n,P(u,v));
v_log_axis_labels(P(a,b),P(c,d),n,P(u,v));

h_axis_masklabels(P(a,b),P(c,d),n,P(u,v));
v_axis_masklabels(P(a,b),P(c,d),n,P(u,v));
h_log_axis_masklabels(P(a,b),P(c,d),n,P(u,v));
v_log_axis_masklabels(P(a,b),P(c,d),n,P(u,v));

The axis commands will put n+1 evenly spaced tick marks on the line. 
The labeling commands will put n+1 evenly spaced labels,
masklabels will put the label on an opaque white rectangle.

Points
------
spot(P(a,b)); dot(P(a,b)); ddot(P(a,b)); box(P(a,b)); bbox(P(a,b));
circ(P(a,b));
ring(P(a,b));

spot, dot and ddot are various sized (in decreasing order) dots.
A circ is a small circle with white interior.
A ring is a small circle with transparent interior.

Arrows
------
arrow(P(a,b),P(c,d));
dart(P(a,b),P(c,d));

A dart is a small arrow.

Labels
------
label(P(a,b),P(u,v),\"label\");
label(P(a,b),\"label\");
label(P(a,b),P(u,v),\"label\",posn);
masklabel(P(a,b),P(u,v),\"label\");
masklabel(P(a,b),\"label\");
masklabel(P(a,b),P(u,v),\"label\",posn);

These commands put a label at the point P(a,b).
P(u,v) is an offset (in true points).
posn will specify the position of the label relative to the basepoint,
and can be c(enter), l(eft), r(ight), t(op), b(ottom) or an
appropriate pair.

Text attributes
---------------
label_color(Color); label_mask(Color); label_pad(len);
label_border(Color, [len]); label_border(len); no_label_border();
font_size(LaTeX size);  font_face(face);
label_angle(theta);

The LaTeX size is a string such as \"Huge\" or \"scriptsize\". The
font face is one of \"rm\" (default), \"bf\", \"sc\", or \"tt\".

Curves
------
ellipse(P(a,b),P(c,d),P(e,f),tmin,tmax);
circle(P(a,b),r);
circle(P(a,b),P(c,d),P(e,f));

Ellipse draws (a,b)+Cos(t)*(c,d)+Sin(t)*(e,f) for tmin <= t <= tmax.

Arcs
----
arc(P(a,b),r,theta1,theta2);
arc_arrow(P(a,b),r,theta1,theta2);

The angles are measured in current angle units (radians by default).

Splines
-------
spline(P(a,b),P(c,d),P(e,f));
spline(P(a,b),P(c,d),P(e,f),P(g,h));

Plotting
--------
plot(f,a,b,n);

This plots the function f from a to b using n+1 evenly spaced points. 
If f is P-valued, then this will be a parametric plot.

Calc plotting
-------------
plot(Deriv(f),a,b,n);
plot(Integral(f),a,b,n);
plot(Integral(f),x0,a,b,n);

plot(Deriv(f)...) plots f'.
plot(Integral(f)...) plots int_a^x f (or if x0 is given, int_x0^x f).

Tangents
--------
tan_line(f,t);
envelope(f,t_min,t_max,n);
tan_field(f,t_min,t_max,n);

tan_line will plot the tangent Line to the graph.
envelope will plot n+1 tangent Lines.
tan_field will plot n+1 tangent vectors.
Here, as above, f can be P-valued.

Vector fields
-------------
slope_field(F,P(a,b),P(c,d),n1,n2);
dart_field(F,P(a,b),P(c,d),n1,n2);
vector_field(F,P(a,b),P(c,d),n1,n2);

The slope_field elements will have fixed length, no arrows.
The dart_field elements will have fixed length, small arrows.
The vector_field elements will have true length.

Fractals
--------
const int seed[] = {N, k1, k2, k3, ... , kn};
fractal(P(a,b),P(c,d),D,seed);

seed determines a path made up of equal space line segments, each of
which can point in the direction 2 pi k/N.  Each integer after N in seed
will specify the direction of the next segment.
fractal will recursively replace each segment in seed by a copy of the
original, up to a depth of D, and draw it from P(a,b) to P(c,d)."
  (setq font-lock-defaults
        '((c++-font-lock-keywords 
           c++-font-lock-keywords-1
           c++-font-lock-keywords-2 
           c++-font-lock-keywords-3)
          nil nil ((?_ . "w")) beginning-of-defun
          (font-lock-mark-block-function . mark-defun)))
  (setq epix-output-buffer (concat "*" (buffer-file-name) " output*"))
  (use-local-map epix-mode-map)
  (if (and epix-insert-template-in-empty-buffer
           (= (point-min) (point-max)))
      (progn
        (if epix-mark-files-as-epix
            (epix-mark-file-as-epix))
        (epix-insert-epix-template))
    (if epix-mark-files-as-epix
        (epix-mark-file-as-epix)))
  (run-hooks 'epix-mode-hook))

;;; flix mode

(defvar flix-mode-map nil
  "The keymap for flix mode.")

(if flix-mode-map
     nil
   (let ((map (copy-keymap c++-mode-map)))
     (define-key map "\C-c\C-k" 'epix-kill-process)
     (define-key map "\C-c\C-x" 'epix-run-epix)
     (define-key map "\C-c\C-l" 'epix-run-elaps)
     (define-key map "\C-c\C-r" 'epix-show-output-buffer)
     (define-key map "\C-c\C-v" 'epix-view-elaps-output)
     (define-key map "\C-c\C-h" 'epix-help)
     (define-key map "\C-c`" 'epix-find-error)
     (define-key map "\C-c\C-f" 'epix-run-flix)
     (define-key map "\C-c\C-w" 'epix-view-mng)
     (setq flix-mode-map map)))

(easy-menu-define flix-mode-menu flix-mode-map
  "flix mode menu"
  '("flix"
    ["Run flix" epix-run-flix t]
    ["View the mng file" epix-view-mng t]
    ["Get help on flix/ePiX" epix-help t]
    ["Show the output buffer" epix-show-output-buffer t]
    ("ePiX"
     ["Run ePiX" epix-run-epix t]
     ["Run elaps" epix-run-elaps t]
     ["View the eps file" epix-view-elaps-output t])))

(define-derived-mode flix-mode c++-mode "flix"
  "flix mode is a major mode for editing flix files.
It is C++ mode with a couple of extra commands:

Run flix on the file being visited:   C-cC-f
View the mng output:                  C-cC-w
Get help on flix:                     C-cC-h

Since a flix file is a valid ePiX file, the
following commands are also available:
Run epix on the file being visited:   C-cC-x
Run elaps on the file being visited:  C-cC-l
View the postscript output:           C-cC-v
In the case of errors:
Go to the (next) error:               C-c`

An ePiX file isn't necessarily a flix file,
but the command
M-x epix-epix-to-flix
will try to turn an ePiX file into a flix file.

SUMMARY OF FLIX/EPIX COMMANDS
------------------------

Preamble
--------
picture(P(a,b), P(c,d), \"height[dim] x width dim\");

The actual picture commands need to be between
begin();
and
end();

Colors
------
RGB(r,g,b);
Red(d);    Green(d);    Blue(d);    Black(d);      White(d);

CMY(c,m,y);
Cyan(d);   Magenta(d);  Yellow(d);  CMY_Black(d);  CMY_White(d);

CMYK(c,m,y,k);
CyanK(d);  MagentaK(d); YellowK(d); CMYK_Black(d); CMYK_White(d);

Primary densities interpolate linearly between anti-saturation (-1),
no color(0), full saturation (1), and saturation on all channels (2 
or -2). Densities are meaningful mod 4. Colors can be superposed, 
blended, inverted, filtered, and scaled.

Line and fill styles
-----------
Widths:  plain([Color]); bold([Color]); bbold([Color]);
         pen(Color, [len]);  pen(len);
         base(Color, [len]); base(len);
Styles:  solid(); dashed(); dotted();
         line_style(string);
Fill:    fill(Color); fill(bool); nofill();

The base pen draws an underlayer/border if wider than the line pen.
line_style accepts a WYSIWYG pattern of spaces, dashes, and periods.

Lines
-----
line(P(a,b),P(c,d));
Line(P(a,b),P(c,d));
Line(P(a,b),m);

The line goes from one point to the other,
the Line is that part of the entire line which lies inside the
bounding box.

Polygons
--------
triangle(P(a,b),P(c,d),P(e,f));
rect(P(a,b),P(c,d));
quad(P(a,b),P(c,d),P(e,f),P(g,h));

Axes
----
h_axis(P(a,b),P(c,d),n);
v_axis(P(a,b),P(c,d),n);
h_log_axis(P(a,b),P(c,d),n);
v_log_axis(P(a,b),P(c,d),n);

h_axis_labels(P(a,b),P(c,d),n,P(u,v));
v_axis_labels(P(a,b),P(c,d),n,P(u,v));
h_log_axis_labels(P(a,b),P(c,d),n,P(u,v));
v_log_axis_labels(P(a,b),P(c,d),n,P(u,v));

h_axis_masklabels(P(a,b),P(c,d),n,P(u,v));
v_axis_masklabels(P(a,b),P(c,d),n,P(u,v));
h_log_axis_masklabels(P(a,b),P(c,d),n,P(u,v));
v_log_axis_masklabels(P(a,b),P(c,d),n,P(u,v));

The axis commands will put n+1 evenly spaced tick marks on the line. 
The labeling commands will put n+1 evenly spaced labels,
masklabels will put the label on an opaque white rectangle.

Points
------
spot(P(a,b)); dot(P(a,b)); ddot(P(a,b)); box(P(a,b)); bbox(P(a,b));
circ(P(a,b));
ring(P(a,b));

spot, dot and ddot are various sized (in decreasing order) dots.
A circ is a small circle with white interior.
A ring is a small circle with transparent interior.

Arrows
------
arrow(P(a,b),P(c,d));
dart(P(a,b),P(c,d));

A dart is a small arrow.

Labels
------
label(P(a,b),P(u,v),\"label\");
label(P(a,b),\"label\");
label(P(a,b),P(u,v),\"label\",posn);
masklabel(P(a,b),P(u,v),\"label\");
masklabel(P(a,b),\"label\");
masklabel(P(a,b),P(u,v),\"label\",posn);

These commands put a label at the point P(a,b).
P(u,v) is an offset (in true points).
posn will specify the position of the label relative to the basepoint,
and can be c(enter), l(eft), r(ight), t(op), b(ottom) or an
appropriate pair.

Text attributes
---------------
label_color(Color); label_mask(Color); label_pad(len);
label_border(Color, [len]); label_border(len); no_label_border();
font_size(LaTeX size);  font_face(face);
label_angle(theta);

The LaTeX size is a string such as \"Huge\" or \"scriptsize\". The
font face is one of \"rm\" (default), \"bf\", \"sc\", or \"tt\".

Curves
------
ellipse(P(a,b),P(c,d),P(e,f),tmin,tmax);
circle(P(a,b),r);
circle(P(a,b),P(c,d),P(e,f));

Ellipse draws (a,b)+Cos(t)*(c,d)+Sin(t)*(e,f) for tmin <= t <= tmax.

Arcs
----
arc(P(a,b),r,theta1,theta2);
arc_arrow(P(a,b),r,theta1,theta2);

The angles are measured in current angle units (radians by default).

Splines
-------
spline(P(a,b),P(c,d),P(e,f));
spline(P(a,b),P(c,d),P(e,f),P(g,h));

Plotting
--------
plot(f,a,b,n);

This plots the function f from a to b using n+1 evenly spaced points. 
If f is P-valued, then this will be a parametric plot.

Calc plotting
-------------
plot(Deriv(f),a,b,n);
plot(Integral(f),a,b,n);
plot(Integral(f),x0,a,b,n);

plot(Deriv(f)...) plots f'.
plot(Integral(f)...) plots int_a^x f (or if x0 is given, int_x0^x f).

Tangents
--------
tan_line(f,t);
envelope(f,t_min,t_max,n);
tan_field(f,t_min,t_max,n);

tan_line will plot the tangent Line to the graph.
envelope will plot n+1 tangent Lines.
tan_field will plot n+1 tangent vectors.
Here, as above, f can be P-valued.

Vector fields
-------------
slope_field(F,P(a,b),P(c,d),n1,n2);
dart_field(F,P(a,b),P(c,d),n1,n2);
vector_field(F,P(a,b),P(c,d),n1,n2);

The slope_field elements will have fixed length, no arrows.
The dart_field elements will have fixed length, small arrows.
The vector_field elements will have true length.

Fractals
--------
const int seed[] = {N, k1, k2, k3, ... , kn};
fractal(P(a,b),P(c,d),D,seed);

seed determines a path made up of equal space line segments, each of
which can point in the direction 2 pi k/N.  Each integer after N in seed
will specify the direction of the next segment.
fractal will recursively replace each segment in seed by a copy of the
original, up to a depth of D, and draw it from P(a,b) to P(c,d)."
  (setq font-lock-defaults
        '((c++-font-lock-keywords 
           c++-font-lock-keywords-1
           c++-font-lock-keywords-2 
           c++-font-lock-keywords-3)
          nil nil ((?_ . "w")) beginning-of-defun
          (font-lock-mark-block-function . mark-defun)))
  (setq epix-output-buffer (concat "*" (buffer-file-name) " output*"))
  (use-local-map flix-mode-map)
  (if (and epix-insert-template-in-empty-buffer
           (= (point-min) (point-max)))
      (progn
        (if epix-mark-files-as-epix
            (epix-mark-file-as-flix))
        (epix-insert-flix-template))
    (if epix-mark-files-as-epix
        (epix-mark-file-as-flix)))
  (run-hooks 'epix-mode-hook)
  (run-hooks 'flix-mode-hook))

(provide 'epix)

;;; ---------------------------------------------------------------------------
;;;   License: LGPL-2.1+ (See file 'Copyright' for details).
;;; ---------------------------------------------------------------------------
;;;
;;;  (c) copyright 2000 Iban Hatchondo <hatchond@emi.u-bordeaux.fr>
;;;  (c) copyright 2000 Julien Boninfante <boninfan@emi.u-bordeaux.fr>
;;;
;;; ---------------------------------------------------------------------------
;;;
;;; A simple RGB color chooser example.
;;;

(in-package #:clim-demo)

;;; Example gadget definition.

(defclass abstract-colored-gadget (basic-gadget) ())
(defclass generic-colored-gadget (abstract-colored-gadget)
  ((color :initform +black+ :accessor colored-gadget-color)))

(defmethod handle-repaint ((gadget generic-colored-gadget) region)
  (declare (ignore region))
  (with-bounding-rectangle* (x1 y1 x2 y2) (sheet-region gadget)
    (draw-rectangle* gadget x1 y1 x2 y2 :ink (colored-gadget-color gadget))))

;;; Slider callback and macro.

(defvar *rgb* '(0 0 0))

;;; Macro defining all the slider-call-back.

(defmacro define-slider-callback (name position)
  `(defun ,(make-symbol name) (gadget value)
     (declare (ignore gadget))
     (setf ,(case position
              (1 `(car *rgb*))
              (2 `(cadr *rgb*))
              (3 `(caddr *rgb*)))
           (/ value 10000))
     (execute-frame-command *application-frame*
                            (list 'com-change-color
                                  (apply #'clim:make-rgb-color
                                         (mapcar #'(lambda (color) (coerce color 'single-float))
                                                 *rgb*))))))

(defvar callback-red (define-slider-callback "SLIDER-R" 1))
(defvar callback-green (define-slider-callback "SLIDER-G" 2))
(defvar callback-blue (define-slider-callback "SLIDER-B" 3))

;;; Test functions.

(defun colorslider ()
  (run-frame-top-level (make-application-frame 'colorslider)))

(define-application-frame colorslider
    () ()
    (:menu-bar nil)
    (:panes
     (text :text-field :value "Pick a color")
     (slider-r :slider
               :drag-callback callback-red
               :value-changed-callback callback-red
               :min-value 0
               :max-value 9999
               :value 0
               :show-value-p t
               :orientation :horizontal
               :width 120)
     (slider-g :slider
               :drag-callback callback-green
               :value-changed-callback callback-green
               :min-value 0
               :max-value 9999
               :orientation :horizontal
               :value 0
               :width 120)
     (slider-b :slider
               :drag-callback callback-blue
               :value-changed-callback callback-blue
               :min-value 0
               :max-value 9999
               :orientation :horizontal
               :value 0
               :width 120)
     (colored (make-pane 'generic-colored-gadget
                         :width 200 :height 90)))
    (:layouts
     (default (vertically ()
                text
                slider-r
                slider-g
                slider-b
                colored))))

(define-colorslider-command com-change-color ((color clim:color))
  (let ((colored (find-pane-named *application-frame* 'colored)))
    (setf (colored-gadget-color colored) color)
    (repaint-sheet colored +everywhere+)))

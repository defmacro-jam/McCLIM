;;; -*- Mode: Lisp; Package: CLIM-CLX; -*-

;;;  (c) copyright 1998,1999,2000 by Michael McDonald (mikemac@mikemac.com)
;;;  (c) copyright 2000,2001 by
;;;           Iban Hatchondo (hatchond@emi.u-bordeaux.fr)
;;;           Julien Boninfante (boninfan@emi.u-bordeaux.fr)
;;;  (c) copyright 2000, 2001, 2014, 2016 by
;;;           Robert Strandh (robert.strandh@gmail.com)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;;; Boston, MA  02111-1307  USA.

(in-package :clim-clx)

(defclass clx-basic-port (standard-port)
  ((display :initform nil
	    :accessor clx-port-display)
   (screen :initform nil
	   :accessor clx-port-screen)
   (window :initform nil
	   :accessor clx-port-window)
   (font-families :initform nil :accessor font-families)
   (cursor-table :initform (make-hash-table :test #'eq)
                 :accessor clx-port-cursor-table)))

(defclass clx-basic-pointer (standard-pointer)
  ((cursor :accessor pointer-cursor :initform :upper-left)))

(defun clx-error-handler (display error-name
			  &rest args
			  &key major asynchronous &allow-other-keys)
  (warn "Received CLX ~A (~A) in process ~W for display ~W."
        error-name major (clim-sys:process-name (clim-sys:current-process)) display)
  ;; We ignore all asynchronous errors to keep the connection.
  ;; 42 is SetInputFocus, we ignore match-errors from that.
  (unless (or asynchronous
              (and (eql major 42)
                   (eq error-name 'xlib:match-error)))
    (apply #'xlib:default-error-handler display error-name args)))

(defgeneric initialize-clx (port))

(defmethod initialize-clx ((port clx-basic-port))
  (let ((options (cdr (port-server-path port))))
    (setf (clx-port-display port)
	  (xlib:open-display (getf options :host)
			     :display (getf options :display-id)
			     :protocol (getf options :protocol)))
    (progn
      (setf (xlib:display-error-handler (clx-port-display port))
	    #'clx-error-handler)
      ;; Uncomment this when debugging CLX backend if asynchronous
      ;; errors become troublesome.
      #+nil
      (setf (xlib:display-after-function (clx-port-display port))
	    #'xlib:display-finish-output))
    (setf (clx-port-screen port)
	  (nth (getf options :screen-id)
	       (xlib:display-roots (clx-port-display port))))
    (setf (clx-port-window port) (xlib:screen-root (clx-port-screen port)))
    (make-cursor-table port)
    (make-graft port)
    (when clim-sys:*multiprocessing-p*
      (setf (port-event-process port)
        (clim-sys:make-process
         (lambda ()
           (loop
             (with-simple-restart
                 (restart-event-loop
                  "Restart CLIM's event loop.")
                 (loop
                   (process-next-event port)) )))
         :name (format nil "~S's event process." port))))))

(defmethod destroy-port :before ((port clx-basic-port))
  (handler-case
      (xlib:close-display (clx-port-display port))
    (stream-error ()
      (xlib:close-display (clx-port-display port) :abort t))))

(defmethod pointer-position ((pointer clx-basic-pointer))
  (let* ((port (port pointer))
         (graft (graft port))
         (mirror (sheet-mirror graft))
         (window (window mirror)))
    (multiple-value-bind (x y same-screen-p)
        (xlib:query-pointer window)
      (when same-screen-p
        (untransform-position (sheet-native-transformation graft) x y)))))

(clim-sys:defmethod* (setf pointer-position) (x y (pointer clx-basic-pointer))
  (let* ((port (port pointer))
         (graft (graft port))
         (mirror (sheet-mirror graft))
         (window (window mirror)))
    (multiple-value-bind (x y)
        (transform-position (sheet-native-transformation graft) x y)
      (xlib:warp-pointer window (round x) (round y)))))

(defmethod set-sheet-pointer-cursor ((port clx-basic-port) (sheet mirrored-sheet-mixin) cursor)
  (let* ((cursor (gethash (or cursor :default) (clx-port-cursor-table port)))
         (mirror (sheet-direct-mirror sheet)))
    (when (and cursor mirror)
      (setf (xlib:window-cursor (window mirror)) cursor))))

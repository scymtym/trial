(in-package #:trial)

(define-pool workbench
  :base 'trial)

(define-asset (workbench heightmap) texture
    (#p"/home/linus/output1.png"
     #p"/home/linus/output2.png"
     #p"/home/linus/output3.png")
  :target :texture-2d-array
  :min-filter :linear
  :wrapping :clamp-to-edge)

(progn
  (defmethod setup-scene ((main main))
    (let ((scene (scene main)))
      (gl:polygon-mode :front-and-back :fill)
      (enter (make-instance 'clipmap :n 255 :levels 3 :texture (asset 'workbench 'heightmap)) scene)
      ;; (enter (make-instance 'vertex-entity :vertex-array (make-asset 'mesh (list (make-quad-grid (/ 16) 4 2)))) scene)
      (enter (make-instance 'editor-camera :move-speed 0.001 :location (vec 0 0.2 0) :name :camera) scene)
      ;;(enter (make-instance 'target-camera :target (vec 0 0 0) :location (vec 0 0.6 0.0000001)) scene)
      ))

  (defmethod setup-pipeline ((main main))
    (let ((pipeline (pipeline main))
          (pass1 (make-instance 'render-pass)))
      (register pass1 pipeline)))

  (maybe-reload-scene))

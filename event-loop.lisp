#|
 This file is a part of trial
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.trial)

(defgeneric add-handler (handler handler-container))
(defgeneric remove-handler (handler handler-container))
(defgeneric handle (event handler))

(defclass handler-container ()
  ((handlers :initform () :accessor handlers)))

(defmethod add-handler (handler (container handler-container))
  (setf (handlers container)
        (cons handler (remove handler (handlers container) :test #'matches))))

(defmethod add-handler ((handlers list) (container handler-container))
  (loop for handler in (handlers container)
        unless (find handler handlers :test #'matches)
        do (push handler handlers))
  (setf (handlers container) handlers))

(defmethod add-handler ((source handler-container) (container handler-container))
  (add-handler (handlers source) container))

(defmethod remove-handler (handler (container handler-container))
  (setf (handlers container)
        (remove handler (handlers container) :test #'matches)))

(defmethod remove-handler ((handlers list) (container handler-container))
  (loop for handler in (handlers container)
        unless (find handler handlers :test #'matches)
        collect handler into cleaned-handlers
        finally (setf (handlers container) cleaned-handlers)))

(defmethod remove-handler ((source handler-container) (container handler-container))
  (remove-handler (handlers source) container))

(defclass event-loop (handler-container)
  ((queue :initform (make-array 0 :initial-element NIL :adjustable T :fill-pointer T) :reader queue)))

(defun issue (loop event-type &rest args)
  (vector-push-extend (apply #'make-instance event-type args) (queue loop)))

(defun process (loop)
  (loop for i from 0
        while (< i (length (queue loop)))
        do (handle (aref (queue loop) i) loop)
           (setf (aref (queue loop) i) NIL))
  (setf (fill-pointer (queue loop)) 0))

(defmethod handle (event (loop event-loop))
  (dolist (handler (handlers loop))
    (handle handler event)))

(defclass handler (named-entity)
  ((event-type :initarg :event-type :accessor event-type)
   (container :initarg :container :accessor container)
   (delivery-function :initarg :delivery-function :accessor delivery-function))
  (:default-initargs
   :event-type (error "EVENT-TYPE required.")
   :container (error "CONTAINER required.")
   :delivery-function (error "DELIVERY-FUNCTION needed.")))

(defmethod handle (event (handler handler))
  (when (typep event (event-type handler))
    (funcall (delivery-function handler) (container handler) event)))

(defmacro define-handler ((class name) event-type args &body body)
  (let ((event (first args))
        (args (rest args)))
    `(add-handler (make-instance
                   'handler
                   :name ',name
                   :event-type ',event-type
                   :container ',class
                   :delivery-function (lambda (,class ,event)
                                        (with-slots ,args ,event
                                          ,@body)))
                  ',class)))

(defclass subject-class (standard-class handler-container)
  ((effective-handlers :initform NIL :accessor effective-handlers)
   (instances :initform () :accessor instances)))

(defmethod c2mop:validate-superclass ((class subject-class) (super t))
  NIL)

(defmethod c2mop:validate-superclass ((class standard-class) (super subject-class))
  T)

(defmethod c2mop:validate-superclass ((class subject-class) (super standard-class))
  T)

(defmethod c2mop:validate-superclass ((class subject-class) (super subject-class))
  T)

(defun cascade-option-changes (class)
  ;; Recompute effective handlers
  (loop with effective-handlers = (handlers class)
        for super in (c2mop:class-direct-superclasses class)
        when (c2mop:subclassp super 'subject-class)
        do (dolist (handler (effective-handlers super))
             (pushnew handler effective-handlers :test #'matches))
        finally (setf (effective-handlers class) effective-handlers))
  ;; Update instances
  (loop for pointer in (instances class)
        for value = (tg:weak-pointer-value pointer)
        when value
        collect (reinitialize-instance value) into instances
        finally (setf (instances class) instances))
  ;; Propagate
  (loop for sub-class in (c2mop:class-direct-subclasses class)
        when (and (c2mop:subclassp sub-class 'subject-class)
                  (c2mop:class-finalized-p sub-class))
        do (cascade-option-changes sub-class)))

(defmethod c2mop:finalize-inheritance :after ((class subject-class))
  (dolist (super (c2mop:class-direct-superclasses class))
    (unless (c2mop:class-finalized-p super)
      (c2mop:finalize-inheritance super)))
  (cascade-option-changes class))

(defmethod add-handler :after (handler (class subject-class))
  (cascade-option-changes class))

(defmethod remove-handler :after (handler (class subject-class))
  (cascade-option-changes class))

(defclass subject (handler-container)
  ((loops :initarg :loops :accessor loops))
  (:default-initargs
   :loops ())
  (:metaclass subject-class))

(defmethod initialize-instance :after ((subject subject) &key)
  (push (tg:make-weak-pointer subject) (instances (class-of subject)))
  (regenerate-handlers subject))

(defmethod reinitialize-instance :after ((subject subject) &key)
  (regenerate-handlers subject))

(defmethod regenerate-handlers ((subject subject))
  (dolist (loop (loops subject))
    (remove-handler subject loop))
  (loop for handler in (handlers (class-of subject))
        collect (make-instance
                 'handler
                 :container subject
                 :name (name handler)
                 :event-type (event-type handler)
                 :delivery-function (delivery-function handler)) into handlers
        finally (setf (handlers subject) handlers))
  (dolist (loop (loops subject))
    (add-handler subject loop)))

(defmethod add-handler (handler (class symbol))
  (add-handler handler (find-class class)))

(defmethod remove-handler (handler (class symbol))
  (remove-handler handler (find-class class)))

(defmacro define-subject (name direct-superclasses direct-slots &optional options)
  (unless (find-if (lambda (c) (c2mop:subclassp c 'subject)) direct-superclasses)
    (push 'subject direct-superclasses))
  (unless (find :metaclass options :key #'first)
    (push '(:metaclass subject-class) options))
  `(defclass ,name ,direct-superclasses
     ,direct-slots
     ,@options))

(defclass event ()
  ())

(defclass tick (event)
  ())

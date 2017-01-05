(import 'class/obj/obj.inc)

(def-class 'ref 'obj)
(def-method 'init 'class/ref/init)
(def-method 'ref 'class/ref/ref 'static '(r0))
(def-method 'deref 'class/ref/deref 'static '(r0))
(def-method 'ref_if 'class/ref/ref_if 'static '(r0))
(def-method 'deref_if 'class/ref/deref_if 'static '(r0))

(def-struct 'ref 'obj)
	(ulong 'ref_count)
(def-struct-end)

;;;;;;;;;;;;;;;
;inline methods
;;;;;;;;;;;;;;;

(defcfun class/ref/ref ()
	;inputs
	;r0 = object
	;trashes
	;r1
	(vp-cpy-ir r0 ref_count r1)
	(vp-inc r1)
	(vp-cpy-ri r1 r0 ref_count))
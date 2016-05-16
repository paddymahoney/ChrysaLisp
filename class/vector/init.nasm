%include 'inc/func.inc'
%include 'class/class_vector.inc'

	fn_function class/vector/init
		;inputs
		;r0 = vector object
		;r1 = vtable pointer
		;outputs
		;r1 = 0 if error, else ok

		;init parent
		p_call vector, init, {r0, r1}, {r1}
		if r1, !=, 0
			;init myself
			vp_xor r2, r2
			vp_cpy r2, [r0 + vector_array]
			vp_cpy r2, [r0 + vector_length]
			vp_cpy r2, [r0 + vector_capacity]
		endif
		vp_ret

	fn_function_end
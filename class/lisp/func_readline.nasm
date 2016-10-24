%include 'inc/func.inc'
%include 'inc/load.inc'
%include 'class/class_vector.inc'
%include 'class/class_stream_str.inc'
%include 'class/class_string.inc'
%include 'class/class_error.inc'
%include 'class/class_lisp.inc'

	def_function class/lisp/func_readline
		;inputs
		;r0 = lisp object
		;r1 = args
		;outputs
		;r0 = lisp object
		;r1 = value

		ptr this, args, value
		pubyte reloc
		long length

		push_scope
		retire {r0, r1}, {this, args}

		slot_call vector, get_length, {args}, {length}
		if {length == 1}
			static_call vector, get_element, {args, 0}, {value}
			if {value->obj_vtable == @class/class_stream_str}
				slot_function sys_load, statics
				assign {@_function_.ld_statics_reloc_buffer}, {reloc}
				static_call stream_str, read_line, {value, reloc, ld_reloc_size}, {length}
				if {length == -1}
					assign {this->lisp_sym_nil}, {value}
					static_call ref, ref, {value}
				else
					static_call string, create_from_buffer, {reloc, length}, {value}
				endif
			else
				static_call error, create, {"(read-line stream) not a stream", args}, {value}
			endif
		else
			static_call error, create, {"(read-line stream) wrong number of args", args}, {value}
		endif

		eval {this, value}, {r0, r1}
		pop_scope
		return

	def_function_end
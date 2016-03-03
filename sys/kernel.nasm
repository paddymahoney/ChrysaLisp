%include 'inc/func.inc'
%include 'inc/mail.inc'
%include 'inc/task.inc'
%include 'inc/link.inc'
%include 'inc/gui.inc'
%include 'inc/sdl2.inc'

;;;;;;;;;;;;;
; kernel task
;;;;;;;;;;;;;

	fn_function sys/kernel
		;loader is already initialized when we get here !
		;inputs
		;r0 = argv pointer

		;save argv on stack
		vp_push r0

		;init tasker
		fn_call sys/task_init

		;init allocator
		fn_call sys/mem_init

		;init linker
		fn_call sys/link_init

		;start kernel task
		fn_call sys/task_start
		fn_bind sys/task_statics, r2
		vp_cpy r1, [r2 + TK_STATICS_CURRENT_TCB]

		;init mailer, r0 = kernel mailbox !
		fn_call sys/mail_init

		;process command options
		vp_cpy [r4], r0
		fn_call sys/opt_process

		;fill in num cpu's with at least mine + 1
		fn_call sys/cpu_get_id
		vp_inc r0
		fn_bind sys/task_statics, r1
		vp_cpy r0, [r1 + TK_STATICS_CPU_TOTAL]

		;allocate for kernel routing table
		vp_sub lk_table_size, r4
		vp_cpy 0, qword[r4 + lk_table_array]
		vp_cpy 0, qword[r4 + lk_table_array_size]

;;;;;;;;;;;;;;;;;;;;;;;
; main kernel task loop
;;;;;;;;;;;;;;;;;;;;;;;

		;loop till no other tasks running
		loop_start
			;allow all other tasks to run
			fn_call sys/task_yield

			;service all kernel mail
			loop_start
				;check if any mail
				fn_bind sys/task_statics, r0
				vp_cpy [r0 + TK_STATICS_CURRENT_TCB], r0
				vp_lea [r0 + TK_NODE_MAILBOX], r0
				ml_check r0, r1
				breakif r1, ==, 0

				;read waiting mail
				fn_call sys/mail_read
				vp_cpy r0, r15

				;switch on kernel call number
				vp_cpy [r15 + (ML_MSG_DATA + kn_data_kernel_function)], r1
				switch
				case r1, ==, fn_call_task_open
				run_here:
					;fill in reply ID, user field is left alone !
					vp_cpy [r15 + (ML_MSG_DATA + kn_data_kernel_reply)], r1
					vp_cpy [r15 + (ML_MSG_DATA + kn_data_kernel_reply + 8)], r2
					vp_cpy r1, [r15 + ML_MSG_DEST]
					vp_cpy r2, [r15 + (ML_MSG_DEST + 8)]

					;open single task and return mailbox ID
					vp_lea [r15 + (ML_MSG_DATA + kn_data_task_open_pathname)], r0
					fn_call sys/load_bind
					fn_call sys/task_start
					vp_cpy r0, [r15 + (ML_MSG_DATA + kn_data_task_open_reply_mailboxid)]
					fn_call sys/cpu_get_id
					vp_cpy r0, [r15 + (ML_MSG_DATA + kn_data_task_open_reply_mailboxid + 8)]
					vp_cpy ML_MSG_DATA + kn_data_task_open_reply_size, qword[r15 + ML_MSG_LENGTH]
					vp_cpy r15, r0
					fn_call sys/mail_send
					break
				case r1, ==, fn_call_task_child
					;find best cpu to run task
					fn_call sys/cpu_get_id
					vp_cpy r0, r5
					fn_bind sys/task_statics, r1
					vp_cpy [r1 + TK_STATICS_TASK_COUNT], r1
					fn_bind sys/link_statics, r2
					loop_list_forwards r2 + lk_statics_links_list, r2, r3
						if r1, >, [r3 + lk_node_task_count]
							vp_cpy [r3 + lk_node_cpu_id], r0
							vp_cpy [r3 + lk_node_task_count], r1
						endif
					loop_end
					jmpif r0, ==, r5, run_here

					;send to better kernel
					vp_cpy r0, [r15 + (ML_MSG_DEST + 8)]
					vp_cpy r15, r0
					fn_call sys/mail_send
					break
				case r1, ==, fn_call_task_route
					;increase size of network ?
					fn_bind sys/task_statics, r0
					vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_origin], r1
					vp_inc r1
					if r1, >, [r0 + TK_STATICS_CPU_TOTAL]
						vp_cpy r1, [r0 + TK_STATICS_CPU_TOTAL]
					endif

					;new kernel routing table ?
					vp_cpy [r4 + lk_table_array], r0
					vp_cpy [r4 + lk_table_array_size], r1
					vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_origin], r11
					vp_mul lk_route_size, r11
					vp_lea [r11 + lk_route_size], r2
					fn_call sys/mem_grow
					vp_cpy r0, [r4 + lk_table_array]
					vp_cpy r1, [r4 + lk_table_array_size]

					;compare hop counts
					vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_hops], r2
					vp_cpy [r0 + r11 + lk_route_hops], r3
					switch
					case r3, ==, 0
						;never seen, so better route
						vp_jmp better_route
					case r2, <, r3
					better_route:
						;new hops is less, so better route
						vp_cpy r2, [r0 + r11]

						;fill in via route and remove other routes
						vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_via], r13
						fn_bind sys/link_statics, r14
						loop_list_forwards r14 + lk_statics_links_list, r14, r12
							;new link route table ?
							vp_cpy [r12 + lk_node_table + lk_table_array], r0
							vp_cpy [r12 + lk_node_table + lk_table_array_size], r1
							vp_lea [r11 + lk_route_size], r2
							fn_call sys/mem_grow
							vp_cpy r0, [r12 + lk_node_table + lk_table_array]
							vp_cpy r1, [r12 + lk_node_table + lk_table_array_size]

							if [r12 + lk_node_cpu_id], ==, r13
								;via route
								vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_hops], r2
								vp_cpy r2, [r0 + r11 + lk_route_hops]
							else
								;none via route
								vp_cpy 0, qword[r0 + r11 + lk_route_hops]
							endif
						loop_end
						break
					case r2, ==, r3
						;new hops is equal, so additional route
						vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_via], r13
						fn_bind sys/link_statics, r14
						loop_list_forwards r14 + lk_statics_links_list, r14, r12
							;new link route table ?
							vp_cpy [r12 + lk_node_table + lk_table_array], r0
							vp_cpy [r12 + lk_node_table + lk_table_array_size], r1
							vp_lea [r11 + lk_route_size], r2
							fn_call sys/mem_grow
							vp_cpy r0, [r12 + lk_node_table + lk_table_array]
							vp_cpy r1, [r12 + lk_node_table + lk_table_array_size]

							if [r12 + lk_node_cpu_id], ==, r13
								;via route
								vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_hops], r2
								vp_cpy r2, [r0 + r11 + lk_route_hops]
							endif
						loop_end
						;drop through to discard message !
					default
						;new hops is greater, so worse route
						vp_jmp drop_msg
					endswitch

					;increment hop count
					vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_hops], r1
					vp_inc r1
					vp_cpy r1, [r15 + ML_MSG_DATA + kn_data_link_route_hops]

					;get current via, set via to my cpu id
					vp_cpy [r15 + ML_MSG_DATA + kn_data_link_route_via], r14
					fn_call sys/cpu_get_id
					vp_cpy r0, [r15 + ML_MSG_DATA + kn_data_link_route_via]

					;copy and send to all neighbors apart from old via
					fn_bind sys/link_statics, r13
					loop_list_forwards r13 + lk_statics_links_list, r13, r12
						vp_cpy [r12 + lk_node_cpu_id], r11
						continueif r11, ==, r14
						fn_call sys/mail_alloc
						vp_cpy r0, r5
						vp_cpy r0, r1
						vp_cpy r15, r0
						vp_cpy [r15 + ML_MSG_LENGTH], r2
						vp_add 7, r2
						vp_and -8, r2
						fn_call sys/mem_copy
						vp_cpy r11, [r5 + (ML_MSG_DEST + 8)]
						vp_cpy r5, r0
						fn_call sys/mail_send
					loop_end
				drop_msg:
					vp_cpy r15, r0
					fn_call sys/mem_free
					break
				case r1, ==, fn_call_gui_update
					;free update message
					vp_cpy r15, r0
					fn_call sys/mem_free

					;create screen window ?
					fn_bind gui/gui_statics, r15
					vp_cpy [r15 + GUI_STATICS_WINDOW], r14
					if r14, ==, 0
						;init sdl2
						sdl_setmainready
						sdl_init SDL_INIT_VIDEO

						;create window
						vp_lea [rel title], r14
						sdl_createwindow r14, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 1024, 768, SDL_WINDOW_OPENGL
						vp_cpy r0, [r15 + GUI_STATICS_WINDOW]

						;create renderer
						sdl_createrenderer r0, -1, SDL_RENDERER_ACCELERATED
						vp_cpy r0, [r15 + GUI_STATICS_RENDERER]

						;set blend mode
						sdl_setrenderdrawblendmode r0, SDL_BLENDMODE_BLEND
					endif

					;update screen
					vp_cpy [r15 + GUI_STATICS_SCREEN], r0
					if r0, !=, 0
						fn_call gui/view_draw
						fn_bind gui/gui_statics, r0
						sdl_renderpresent [r0 + GUI_STATICS_RENDERER]
					endif
					break
				default
				endswitch
			loop_end

			;get time
			fn_call sys/cpu_get_time

			;start any tasks ready to restart
			fn_bind sys/task_statics, r3
			vp_cpy [r3 + TK_STATICS_TIMER_LIST + LH_LIST_HEAD], r2
			ln_get_succ r2, r2
			if r2, !=, 0
				loop_list_forwards r3 + TK_STATICS_TIMER_LIST, r2, r1
					vp_cpy [r1 + TK_NODE_TIME], r5
					breakif r5, >, r0

					;task ready, remove from timer list and place on ready list
					vp_cpy r1, r5
					ln_remove_node r5, r6
					ln_add_node_before r15, r1, r6
				loop_end
			endif

			;next task if other ready tasks
			vp_cpy [r3 + TK_STATICS_TASK_LIST + LH_LIST_HEAD], r2
			vp_cpy [r3 + TK_STATICS_TASK_LIST + LH_LIST_TAILPRED], r1
			continueif r2, !=, r1

			;exit if no task waiting for timer
			vp_cpy [r3 + TK_STATICS_TIMER_LIST + LH_LIST_HEAD], r2
			ln_get_succ r2, r1
			breakif r1, ==, 0

			;sleep till next wake time
			vp_xchg r0, r2
			vp_cpy [r0 + TK_NODE_TIME], r0
			vp_sub r2, r0
			vp_cpy 1000, r3
			vp_xor r2, r2
			vp_div r3
			if r0, <, 1
				vp_cpy 1, r0
			endif
			sdl_delay r0
		loop_end

		;deinit gui
		fn_call gui/gui_deinit

		;free any kernel routing table
		vp_cpy [r4 + lk_table_array], r0
		fn_call sys/mem_free
		vp_add lk_table_size, r4

		;deinit allocator
		fn_call sys/mem_deinit

		;deinit mailer
		fn_call sys/mail_deinit

		;deinit tasker
		fn_call sys/task_deinit

		;deinit loader
		fn_call sys/load_deinit

		;pop argv and exit !
		vp_add 8, r4
		sys_exit 0

	title:
		db 'Asm Kernel GUI Window', 0

	fn_function_end

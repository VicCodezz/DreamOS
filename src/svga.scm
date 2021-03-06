;;;;;;;;;;;;;;;;;;;
;;; SVGA Driver ;;;
;;;;;;;;;;;;;;;;;;;

(define HORIZONTAL_PIXELS 1024)
(define VERTICAL_PIXELS 768)
(define BYTES_PER_PIXEL 2)
(define BYTES_PER_PIXEL_ROW (* HORIZONTAL_PIXELS BYTES_PER_PIXEL))
(define BYTES_PER_SCREEN (* BYTES_PER_PIXEL_ROW VERTICAL_PIXELS))
(define PIXHEIGHT 16)
(define BYTES_PER_ROW (* BYTES_PER_PIXEL_ROW PIXHEIGHT))
(define BYTES_PER_COLUMN (* 8 BYTES_PER_PIXEL))

(define (cursor-offset row col)
  (+ (* row BYTES_PER_ROW) (* col BYTES_PER_COLUMN)))

(: 'north)
  (mov #x0cf8 edx)
  (out dx)
  (add 4 edx)
  (in dx)
  (ret)

(: 'dev)
  (mov #x80001008 eax)
  ;Find display, start at bus 0 device 2
  (mov 30 ecx) ;end with AGP: 10008, bus 1, dev 0
(: 'dev_loop)
  (push eax)
  (call 'north)
  (and! #xff000000 eax)
  (cmp #x03000000 eax)
  (pop eax)
  (jz 'dev_end)
  (add #x0800 eax)
  (loop 'dev_loop)
(: 'dev_end)
  (ret)

(: 'ati0)
  (call 'dev)
  (or! 2 (@ -4 eax))
  (add (- #x24 8) eax)

  (movb 5 cl)
(: 'ati_loop)
  (push eax)
  (call 'north)
  (xorb 8 al)
  (jz 'ati_end)
  (pop eax)
  (sub 4 eax)
  (loop 'ati_loop)
  (push eax)
  (call 'north)
  (and! #xfffffff0 eax)
(: 'ati_end)
  (mov eax (@ 'displ))
  (mov eax (@ 'displ_end))
  (add BYTES_PER_SCREEN (@ 'displ_end))
  (mov -1 eax)
  (mov (quotient (* PIXHEIGHT BYTES_PER_COLUMN) 4) ecx)
  (mov 'cursor_foreground edi)
  (rep)(stos)
  (pop eax)
  (ret)

(: 'puts_backspace)
  (mov (char->integer #\space) eax)
  (push 'puts_loop_next) ;continuation
  (test (- BYTES_PER_PIXEL_ROW 1) edi)
  (jz 'puts_backspace_backline)
  (sub BYTES_PER_COLUMN edi)
  (jmpl 'puts_pixmap)
(: 'puts_backspace_backline)
  (cmp 0 edi)
  (jel 'puts_pixmap)
  (sub (+ BYTES_PER_COLUMN BYTES_PER_ROW (- BYTES_PER_PIXEL_ROW)) edi)
  (jmp 'puts_pixmap)

(: 'puts_video)
  (mov ecx esi)
  (mov (@ 'str_len) ecx)
(: 'puts_video_esi_ecx)
  (mov (@ 'cursor) edi)

(: 'puts_loop)
  (clear eax)
  (lodsb)
  (cmpb 8 al) ;backspace
  (je 'puts_backspace)
  (cmpb 10 al) ;newline
  (jne 'puts_loop_char)
  (call 'put_newline)
  (jmp 'puts_loop_next)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw character whose ascii is eax
;; onto screen starting at screen offset edi
(: 'puts_pixmap)
  (push esi)
  (push edx)
  (push ebx)
  (push ecx)
  (push edi)
  (shl 4 eax) ;(* PIXHEIGHT eax)
  (add 'pixmaps eax)
  (mov eax esi)
  (mov PIXHEIGHT ecx)

  (add (@ 'displ) edi)
  (mov (@ 'vga_background) ebx)
  (mov (@ 'vga_foreground) edx)
(: 'puts_pixmap_loop)
  (lodsb)

  (push ecx)
  (mov 8 ecx)
(: 'puts_pixmap_byte_loop)
  (shlb 1 al)
  (jc 'puts_foreground)
  (opd-size)(mov bx (@ edi))
  (jmp 'puts_pixmap_next)

(: 'puts_foreground)
  (opd-size)(mov dx (@ edi))
(: 'puts_pixmap_next)
  (add 2 edi)
  (loop 'puts_pixmap_byte_loop)
  (pop ecx)

  (add (- BYTES_PER_PIXEL_ROW BYTES_PER_COLUMN) edi)
  (loop 'puts_pixmap_loop)

  (pop edi)
  (pop ecx)
  (pop ebx)
  (pop edx)
  (pop esi)
  (ret)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(: 'puts_loop_char)
  (call 'puts_pixmap)

  (add BYTES_PER_COLUMN edi)
  (test (- BYTES_PER_PIXEL_ROW 1) edi)
  (jnz 'puts_pixmap_sameline)
  (add (- BYTES_PER_ROW BYTES_PER_PIXEL_ROW) edi)
(: 'puts_pixmap_sameline)
  (call 'conditional_scroll)
(: 'puts_loop_next)
  (loop 'puts_loop)

(: 'move_cursor)
  (mov edi (@ 'cursor))
  (popa)
  (ret)

(: 'put_newline)
  (shr 15 edi) ;(quotient edi BYTES_PER_ROW)
  (inc edi)
  (shl 15 edi)

(: 'conditional_scroll)
  (cmp BYTES_PER_SCREEN edi)
  (jb 'no_console_scroll)
  (call 'console_scroll)
  (mov (cursor-offset (- SCREEN_ROWS SCROLL_ROWS) 0) edi)
(: 'no_console_scroll)
  (ret)

(: 'draw_cursor)
  (push eax)
  (push esi)
  (push edx)
  (mov 'cursor_foreground edx)
  (mov (@ 'cursor) esi)
  (add (@ 'displ) esi)
  (mov 'cursor_background edi)
  (mov 16 ecx)
  (jmp 'draw_cursor_loop_begin)

(: 'draw_cursor_loop)
  (add (- BYTES_PER_PIXEL_ROW BYTES_PER_COLUMN) esi)
  (add BYTES_PER_COLUMN edx)
(: 'draw_cursor_loop_begin)
  (movs)
  (mov (@ edx) eax)
  (call 'cursor_pixel_pair)
  (movs)
  (mov (@ 4 edx) eax)
  (call 'cursor_pixel_pair)
  (movs)
  (mov (@ 8 edx) eax)
  (call 'cursor_pixel_pair)
  (movs)
  (mov (@ 12 edx) eax)
  (call 'cursor_pixel_pair)
  (loop 'draw_cursor_loop)

  (pop edx)
  (pop esi)
  (pop eax)
  (ret)

(: 'cursor_pixel_pair)
  (test #xffff eax)
  (jz 'cursor_pixel_pair_continue)
  (opd-size)(mov eax (@ -4 esi))
(: 'cursor_pixel_pair_continue)
  (test #xffff0000 eax)
  (jz 'cursor_pixel_pair_end)
  (shr 16 eax)
  (opd-size)(mov eax (@ -2 esi))
(: 'cursor_pixel_pair_end)
  (ret)

(: 'erase_cursor)
  (push eax)
  (push esi)
  (mov 16 ecx)
  (mov (@ 'cursor) edi)
  (add (@ 'displ) edi)
  (mov 'cursor_background esi)
  (jmp 'erase_cursor_loop_begin)

(: 'erase_cursor_loop)
  (add (- BYTES_PER_PIXEL_ROW BYTES_PER_COLUMN) edi)
(: 'erase_cursor_loop_begin)
  (movs)
  (movs)
  (movs)
  (movs)
  (loop 'erase_cursor_loop)

  (pop esi)
  (pop eax)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-scroll-up")
  (insure-no-more-args ARGL)
(: 'console_scroll)
  (push eax)
  (push esi)
  (push ecx)
; Move all but top row up one row
  (mov (@ 'displ) edi)
  (mov (* SCROLL_ROWS BYTES_PER_ROW) esi)
  (add edi esi)
  (mov (quotient (- BYTES_PER_SCREEN (* SCROLL_ROWS BYTES_PER_ROW)) 4) ecx)
  (rep)(movs)
; Clear bottom row
  (mov 0 eax)
  (mov (quotient (* SCROLL_ROWS BYTES_PER_ROW) 4) ecx)
  (rep)(stos)
  (pop ecx)
  (pop esi)
  (pop eax)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-pixmap-address")
  (call 'get_last_char_ascii)
  (shl 4 TEMP)
  (add 'pixmaps TEMP)
  (mov (object INTEGER TEMP) VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-display-address")
  (insure-no-more-args ARGL)
  (mov (@ 'displ) TEMP)
  (mov (object INTEGER TEMP) VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-set-cursor")
  (call 'get_last_string)
  (mov (@ 4 ARGL) esi)
  (mov (* 4 16) ecx)
  (mov 'cursor_foreground edi)
  (rep)(movs)
  (clear eax esi edi)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-clear")
  (insure-no-more-args ARGL)
  (mov (@ 'displ) edi)
  (mov (quotient BYTES_PER_SCREEN 4) ecx)
  (clear eax)
  (rep)(stos)
  (clear edi)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-clear-row")
  (insure-no-more-args ARGL)
  (mov (@ 'cursor) edi)
  (add (@ 'displ) edi)
  (mov (@ 'vga_background) eax)
  (mov edi edx)
  (and! (- BYTES_PER_PIXEL_ROW 1) edx)
  (mov 16 ecx)
  (jmp 'vga_clear_row_inner_loop)

(: 'vga_clear_row_loop)
  (add edx edi)
(: 'vga_clear_row_inner_loop)
  (opd-size)(stos)
  (test (- BYTES_PER_PIXEL_ROW 1) edi)
  (jnz 'vga_clear_row_inner_loop)
  (loop 'vga_clear_row_loop)

  (clear edi edx)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-position-x")
  (insure-no-more-args ARGL)
  (mov (@ 'cursor) VAL)
  (mov BYTES_PER_ROW TEMP)
  (cdq)
  (div TEMP)
  (shr 4 edx) ;(quotient edx BYTES_PER_COLUMN)
  (mov INTEGER (@ FREE))
  (mov edx (@ 4 FREE))
  (mov FREE VAL)
  (clear edx)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-position-y")
  (insure-no-more-args ARGL)
  (mov (@ 'cursor) VAL)
  (mov BYTES_PER_ROW TEMP)
  (cdq)
  (div TEMP)
  (mov INTEGER (@ FREE))
  (mov VAL (@ 4 FREE))
  (mov FREE VAL)
  (clear edx)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-set-position")
  (insure-more-args ARGL)
  (call 'get_exact_natural)
  (pusha)
  (mov (@ 4 TEMP) eax)
  (mov BYTES_PER_ROW TEMP)
  (mul TEMP)
  (clear edx)
  (mov (@ 4 ARGL) ARGL)
  (call 'get_last_exact_natural)
  (mov (@ 4 TEMP) TEMP)
  (shl 4 TEMP) ;(* BYTES_PER_COLUMN ecx)
  (add TEMP eax)
  (jsl 'error_invalid_index)
  (cmp BYTES_PER_SCREEN eax)
  (jael 'error_invalid_index)
  (mov eax edi)
  (jmpl 'move_cursor)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-draw-box")
  (insure-more-args ARGL)
  (call 'get_exact_natural)
  (push (@ 4 TEMP)) ;x coord
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (call 'get_exact_natural)
  (push (@ 4 TEMP)) ;y coord
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (call 'get_exact_natural)
  (push (@ 4 TEMP)) ;width
  (mov (@ 4 ARGL) ARGL)
  (call 'get_last_exact_natural)
  (mov (@ 4 TEMP) ecx) ;height
  (cmp 0 ecx)
  (jlel 'error_invalid_index)
  (pop esi) ;width
  (cmp 0 esi)
  (jlel 'error_invalid_index)
  (pop eax) ;y coord
  (cmp 0 eax)
  (jll 'error_invalid_index)
  (mov BYTES_PER_PIXEL_ROW edx)
  (mul edx)
  (pop edi) ;x coord
  (cmp 0 edi)
  (jll 'error_invalid_index)
  (shl 1 edi)
  (add eax edi)

  (add (@ 'displ) edi)
  (cmp (@ 'displ_end) edi)
  (ja 'vga_draw_box_escape)
  (mov (@ 'vga_foreground) edx)
(: 'vga_draw_box_loop)
  (push edi)
  (push ecx)
  (mov esi ecx)
(: 'vga_draw_box_byte_loop)
  (opd-size)(mov dx (@ edi))
(: 'vga_draw_box_next)
  (add 2 edi)
  (loop 'vga_draw_box_byte_loop)
  (pop ecx)
  (pop edi)

  (add BYTES_PER_PIXEL_ROW edi)
  (loop 'vga_draw_box_loop)
(: 'vga_draw_box_escape)
  (clear esi edi eax edx)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-foreground")
  (insure-no-more-args ARGL)
  (mov (@ 'vga_foreground) TEMP)
  (mov INTEGER (@ FREE))
  (mov TEMP (@ 4 FREE))
  (mov FREE VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-set-foreground")
  (call 'get_last_exact_natural)
  (mov (@ 4 TEMP) TEMP)
  (mov TEMP (@ 'vga_foreground))
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-background")
  (insure-no-more-args ARGL)
  (mov (@ 'vga_background) TEMP)
  (mov INTEGER (@ FREE))
  (mov TEMP (@ 4 FREE))
  (mov FREE VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-set-background")
  (call 'get_last_exact_natural)
  (mov (@ 4 TEMP) TEMP)
  (mov TEMP (@ 'vga_background))
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-draw-pixmap")
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_draw_pixmap_escape)
  (push (@ 4 TEMP))
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jne 'vga_draw_pixmap_end)
  (mov (@ 4 TEMP) eax)
  (mov (* 1024 2) TEMP)
  (mul TEMP)
  (pop TEMP)
  (shl 1 TEMP)
  (add eax TEMP)
  (add (@ 'displ) TEMP)
  (push TEMP) ;upper-left pixel
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) EXP) ;pixel map
  (jmp 'vga_draw_pixmap_loop_begin)

(: 'vga_draw_pixmap_next_row)
  (mov (@ 4 EXP) EXP)
  (add (* 1024 2) (@ esp))
(: 'vga_draw_pixmap_loop_begin)
  (test EXP EXP)
  (jz 'vga_draw_pixmap_end)
  (mov (@ EXP) TEMP) ;row
  (mov (@ esp) ARGL)
  (cmp (@ 'displ_end) ARGL)
  (jal 'vga_draw_pixmap_end)
  (jmp 'vga_draw_pixmap_row_begin)

(: 'vga_draw_pixmap_row)
  (mov (@ TEMP) VAL)
  (test VAL VAL)
  (jz 'vga_draw_pixmap_next_pixel)
  (mov (@ 4 VAL) VAL) ;assuming VAL is an INTEGER
  (opd-size)(mov VAL (@ ARGL))
(: 'vga_draw_pixmap_next_pixel)
  (add 2 ARGL)
  (mov (@ 4 TEMP) TEMP)
(: 'vga_draw_pixmap_row_begin)
  (test TEMP TEMP)
  (jnz 'vga_draw_pixmap_row)
  (jmp 'vga_draw_pixmap_next_row)
  
(: 'vga_draw_pixmap_end)
  (pop TEMP) ;discard
(: 'vga_draw_pixmap_escape)
  (clear VAL ARGL)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-test-pixmap")
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_test_pixmap_escape)
  (push (@ 4 TEMP))
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jne 'vga_test_pixmap_false)
  (mov (@ 4 TEMP) eax)
  (mov (* 1024 2) TEMP)
  (mul TEMP)
  (pop TEMP)
  (shl 1 TEMP)
  (add eax TEMP)
  (add (@ 'displ) TEMP)
  (push TEMP) ;upper-left pixel
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) EXP) ;pixel map
  (jmp 'vga_test_pixmap_loop_begin)

(: 'vga_test_pixmap_next_row)
  (mov (@ 4 EXP) EXP)
  (add (* 1024 2) (@ esp))
(: 'vga_test_pixmap_loop_begin)
  (test EXP EXP)
  (jz 'vga_test_pixmap_false)
  (mov (@ EXP) TEMP) ;row
  (mov (@ esp) ARGL)
  (cmp (@ 'displ_end) ARGL)
  (jal 'vga_test_pixmap_false)
  (jmp 'vga_test_pixmap_row_begin)

(: 'vga_test_pixmap_row)
  (mov (@ TEMP) VAL)
  (test VAL VAL)
  (jz 'vga_test_pixmap_next_pixel)
  (opd-size)(cmp 0 (@ ARGL))
  (jne 'vga_test_pixmap_true)
(: 'vga_test_pixmap_next_pixel)
  (add 2 ARGL)
  (mov (@ 4 TEMP) TEMP)
(: 'vga_test_pixmap_row_begin)
  (test TEMP TEMP)
  (jnz 'vga_test_pixmap_row)
  (jmp 'vga_test_pixmap_next_row)
  
(: 'vga_test_pixmap_false)
  (pop TEMP) ;discard
(: 'vga_test_pixmap_escape)
  (clear ARGL)
  (return-false)

(: 'vga_test_pixmap_true)
  (pop TEMP) ;discard
  (mov INTEGER (@ FREE))
  (clear TEMP)
  (opd-size)(mov (@ ARGL) TEMP)
  (clear ARGL)
  (mov TEMP (@ 4 FREE))
  (mov FREE VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-draw-line")
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_draw_line_end)
  (mov (@ 4 TEMP) TEMP)
  (mov TEMP (@ 'vga_draw_line_x))
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_draw_line_end)
  (mov (@ 4 TEMP) TEMP)
  (mov TEMP (@ 'vga_draw_line_y))
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_draw_line_end)
  (mov (@ 4 TEMP) TEMP)
  (sub (@ 'vga_draw_line_x) TEMP)
  (mov 2 (@ 'vga_draw_line_xi))
  (test TEMP TEMP)
  (jns 'vga_draw_line_dx_pos)
  (mov -2 (@ 'vga_draw_line_xi))
  (neg TEMP)
(: 'vga_draw_line_dx_pos)
  (mov TEMP (@ 'vga_draw_line_dx))
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_draw_line_end)
  (mov (@ 4 TEMP) TEMP)
  (sub (@ 'vga_draw_line_y) TEMP)
  (mov 2048 (@ 'vga_draw_line_yi))
  (test TEMP TEMP)
  (jns 'vga_draw_line_dy_pos)
  (mov -2048 (@ 'vga_draw_line_yi))
  (neg TEMP)
(: 'vga_draw_line_dy_pos)
  (mov TEMP (@ 'vga_draw_line_dy))
  (cmp (@ 'vga_draw_line_dx) TEMP)
  (jle 'vga_draw_line_ind)
  (mov TEMP VAL)
  (mov (@ 'vga_draw_line_dx) TEMP)
  (mov TEMP (@ 'vga_draw_line_dy))
  (mov VAL (@ 'vga_draw_line_dx))
  (mov (@ 'vga_draw_line_yi) VAL)
  (mov (@ 'vga_draw_line_xi) TEMP)
  (mov TEMP (@ 'vga_draw_line_yi))
  (mov VAL (@ 'vga_draw_line_xi))
(: 'vga_draw_line_ind)
  (mov (@ 'vga_draw_line_dx) TEMP)
  (mov (@ 4 ARGL) ARGL)
  (insure-no-more-args ARGL)
  (mov (@ 'vga_draw_line_y) EXP)
  (shl 11 EXP)
  (mov (@ 'vga_draw_line_x) VAL)
  (shl 1 VAL)
  (add VAL EXP)
  (add (@ 'displ) EXP) ;Now EXP holds start address
  (mov (@ 'vga_draw_line_dy) ARGL)
  (mov ARGL UNEV)
  (mov ARGL VAL)
  (sub (@ 'vga_draw_line_dx) ARGL)
  (shl 1 ARGL)
  (shl 1 UNEV)
  (shl 1 VAL)
  (sub (@ 'vga_draw_line_dx) VAL)
  (mov (@ 'vga_foreground) ENV)
  (inc TEMP)
(: 'vga_draw_line_loop)
  (opd-size)(mov ENV (@ EXP))
  (add (@ 'vga_draw_line_xi) EXP)
  (test VAL VAL)
  (js 'vga_draw_line_d_neg)
  (add ARGL VAL)
  (add (@ 'vga_draw_line_yi) EXP)
  (jmp 'vga_draw_line_continue)
(: 'vga_draw_line_d_neg)
  (add UNEV VAL)
(: 'vga_draw_line_continue)
  (loop 'vga_draw_line_loop)
(: 'vga_draw_line_end)
  (clear VAL ARGL UNEV EXP ENV)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-additional-primitive "vga-read-pixmap!")
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jnel 'vga_read_pixmap_escape)
  (push (@ 4 TEMP))
  (mov (@ 4 ARGL) ARGL)
  (insure-more-args ARGL)
  (mov (@ ARGL) TEMP)
  (test TEMP TEMP)
  (jzl 'error_expected_number)
  (cmp INTEGER (@ TEMP))
  (jne 'vga_read_pixmap_done)
  (mov (@ 4 TEMP) eax)
  (mov (* 1024 2) TEMP)
  (mul TEMP)
  (pop TEMP)
  (shl 1 TEMP)
  (add eax TEMP)
  (add (@ 'displ) TEMP)
  (push TEMP) ;upper-left pixel
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) EXP) ;pixel map
  (clear UNEV)
  (jmp 'vga_read_pixmap_loop_begin)

(: 'vga_read_pixmap_next_row)
  (mov (@ 4 EXP) EXP)
  (add (* 1024 2) (@ esp))
(: 'vga_read_pixmap_loop_begin)
  (test EXP EXP)
  (jz 'vga_read_pixmap_done)
  (mov (@ EXP) TEMP) ;row
  (mov (@ esp) ARGL)
  (cmp (@ 'displ_end) ARGL)
  (jal 'vga_read_pixmap_done)
  (jmp 'vga_read_pixmap_row_begin)

(: 'vga_read_pixmap_row)
  (mov (@ TEMP) VAL)
  (test VAL VAL)
  (jz 'vga_read_pixmap_next_pixel)
  (opd-size)(mov (@ ARGL) UNEV)
  (mov UNEV (@ 4 VAL))
(: 'vga_read_pixmap_next_pixel)
  (add 2 ARGL)
  (mov (@ 4 TEMP) TEMP)
(: 'vga_read_pixmap_row_begin)
  (test TEMP TEMP)
  (jnz 'vga_read_pixmap_row)
  (jmp 'vga_read_pixmap_next_row)
  
(: 'vga_read_pixmap_done)
  (pop TEMP) ;discard
(: 'vga_read_pixmap_escape)
  (clear ARGL UNEV)
  (ret)
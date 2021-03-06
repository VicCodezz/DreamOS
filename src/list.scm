;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;This program is distributed under the terms of the       ;;;
;;;GNU General Public License.                              ;;;
;;;Copyright (C) 2009 David Joseph Stith                    ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;
;; List Primitives ;;
;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "cons")
  (mov ARGL VAL)
  (insure-more-args VAL)
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (mov ARGL (@ 4 VAL))
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (cxxxxr path)
  (define n (- (string-length path) 1))
  (if (< n 4)
    (begin
      (new-primitive (string-append "c" path "r"))
      (insure-one-last-arg ARGL)
      (mov (@ ARGL) ARGL)
      (: (string->symbol (string-append "c" path "r")))
      (call 'insure_pair)
      (let ((x (string-ref path n))
            (r (substring path 0 n)))
        (mov
          (@ (if (char=? x #\a) 0 4) ARGL)
          (if (zero? n) VAL ARGL))
        (if (zero? n)
          (ret)
          (jmpl (string->symbol (string-append "c" r "r"))))
        (cxxxxr (next-path path n))))))
(define (next-path path n)
  (let ((x (string-ref path n)))
    (case x
      ((#\a)
       (string-set! path n #\d)
       path)
      ((#\d)
       (string-set! path n #\a)
       (if (zero? n)
         (string-append "a" path)
         (next-path path (- n 1)))))))
(cxxxxr "a")
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define (set-cxr offset)
  (insure-more-args ARGL)
  (mov (@ 4 ARGL) VAL)
  (mov (@ ARGL) ARGL)
  (insure-pair ARGL)
  (insure-one-last-arg VAL)
  (mov (@ VAL) VAL)
  (mov VAL (@ offset ARGL))
  (ret))

(new-primitive "set-car!")
  (set-cxr 0)
(new-primitive "set-cdr!")
  (set-cxr 4)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "list")
  (mov ARGL VAL)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "reverse")
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (test ARGL ARGL)
  (jz 'prim_list)
  (insure-object-is-pair ARGL)
  (jmpl 'reverse)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(: 'prim_append_null)
  (clear VAL)
  (ret)
(: 'prim_append_simple)
  (mov EXP VAL)
(: 'append_end)
  (ret)
(new-primitive "append")
  (test ARGL ARGL)
  (jz 'prim_append_null)
(: 'prim_append_recurse)
  (mov (@ ARGL) EXP)
  (mov (@ 4 ARGL) ARGL)
  (test ARGL ARGL)
  (jz 'prim_append_simple)
  (save EXP)
  (call 'prim_append_recurse)
  (restore EXP)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Append VAL to end of list in EXP
;;Return list in VAL
(: 'append)
  (test EXP EXP)
  (jz 'append_end)
  (insure-object-is-pair EXP)
  (mov (@ EXP) TEMP)
  (save TEMP)
  (mov (@ 4 EXP) EXP)
  (call 'append)
  (restore EXP)
  (mov (object EXP VAL) VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "length")
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (clear TEMP)
  (test ARGL ARGL)
  (ifnz
    (begin
      (insure-object-is-pair ARGL)
     (: 'prim_length_loop)
      (inc TEMP)
      (mov (@ 4 ARGL) ARGL)
      (test ARGL ARGL)
      (jnz 'prim_length_loop)))
  (mov INTEGER (@ FREE))
  (mov TEMP (@ 4 FREE))
  (mov FREE VAL)
  (jmpl 'advance_free)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "list-tail")
  (insure-more-args ARGL)
  (mov (@ ARGL) VAL)
  (mov (@ 4 ARGL) ARGL)
  (call 'get_last_exact_natural)
  (mov (@ 4 TEMP) TEMP)
  (jmp 'prim_list_tail_loop_begin)
(: 'prim_list_tail_loop)
  (test VAL VAL)
  (jzl 'error_expected_pair)
  (insure-object-is-pair VAL)
  (mov (@ 4 VAL) VAL)
(: 'prim_list_tail_loop_begin)
  (dec TEMP)
  (jns 'prim_list_tail_loop)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "list-ref")
  (call-prim "list-tail")
  (test VAL VAL)
  (jzl 'error_expected_pair)
  (insure-object-is-pair VAL)
  (mov (@ VAL) VAL)
  (ret)
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "memv")
  (mov 1 (@ 'thunk))
  (jmp 'prim_mem)

(new-primitive "memq")
  (mov 0 (@ 'thunk))
(: 'prim_mem)
  (insure-more-args ARGL)
  (mov (@ ARGL) VAL)
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (jmp 'prim_mem_begin)
(: 'prim_mem_loop)
  (mov (@ 4 ARGL) ARGL)
(: 'prim_mem_begin)
  (test ARGL ARGL)
  (jzl 'return_false)
  (insure-object-is-pair ARGL)
  (mov (@ ARGL) EXP)
  (cmp EXP VAL)
  (je 'prim_mem_found)
  (cmp 0 (@ 'thunk))
  (je 'prim_mem_loop) ;memq gives up here
  (test VAL VAL)
  (jz 'prim_mem_loop)
  (test EXP EXP)
  (jz 'prim_mem_loop)
  (mov (@ VAL) TEMP)
  (cmp (@ EXP) TEMP)
  (jne 'prim_mem_loop)
  (test 1 TEMP) ;Pairs are not allowed to be eqv? unless eq?
  (jz 'prim_mem_loop)
  (cmpb TYPE_VECTOR TEMP) ;Vectors are not allowed to be eqv? unless eq?
  (je 'prim_mem_loop)
  (cmpb SYMBOL TEMP) ;Symbols are not allowed to be eqv? unless eq?
  (je 'prim_mem_loop)
  (mov (@ 4 VAL) TEMP)
  (cmp (@ 4 EXP) TEMP)
  (jne 'prim_mem_loop)
(: 'prim_mem_found)
  (mov ARGL VAL)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "member")
  (insure-more-args ARGL)
  (mov (@ ARGL) VAL)
  (push ARGL) ;for reuse when calling equal?.
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (jmp 'prim_member_begin)

(: 'prim_member_loop)
  (mov (@ 4 ARGL) ARGL)
(: 'prim_member_begin)
  (test ARGL ARGL)
  (jzl 'prim_member_false)
  (insure-object-is-pair ARGL)
  (mov (@ ARGL) EXP)
  (cmp EXP VAL)
  (je 'prim_member_found)
  (push ARGL)
  (mov (@ 4 SP) ARGL)
  (mov EXP (@ ARGL))
  (mov (@ 4 ARGL) TEMP)
  (mov VAL (@ TEMP))
  (push VAL)
  (call-prim "equal?")
  (mov VAL TEMP)
  (pop VAL)
  (pop ARGL)
  (cmp 'false TEMP)
  (je 'prim_member_loop)
(: 'prim_member_found)
  (mov ARGL VAL)
  (add 4 SP)
  (ret)

(: 'prim_member_false)
  (add 4 SP)
  (return-false)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "assv")
  (mov 1 (@ 'thunk))
  (jmp 'prim_ass)
(new-primitive "assq")
  (mov 0 (@ 'thunk))
(: 'prim_ass)
  (insure-more-args ARGL)
  (mov (@ ARGL) VAL)
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (jmp 'prim_ass_begin)
(: 'prim_ass_loop)
  (mov (@ 4 ARGL) ARGL)
(: 'prim_ass_begin)
  (test ARGL ARGL)
  (jzl 'return_false)
  (insure-object-is-pair ARGL)
  (mov (@ ARGL) EXP)
  (insure-object-is-pair EXP)
  (mov (@ EXP) EXP)
  (cmp EXP VAL)
  (je 'prim_ass_found)
  (cmp 0 (@ 'thunk))
  (je 'prim_ass_loop) ;assq gives up here
  (test VAL VAL)
  (jz 'prim_ass_loop)
  (test EXP EXP)
  (jz 'prim_ass_loop)
  (mov (@ VAL) TEMP)
  (cmp (@ EXP) TEMP)
  (jne 'prim_ass_loop)
  (test 1 TEMP) ;Pairs are not allowed to be eqv? unless eq?
  (jz 'prim_ass_loop)
  (cmpb TYPE_VECTOR TEMP) ;Vectors are not allowed to be eqv? unless eq?
  (je 'prim_ass_loop)
  (cmpb SYMBOL TEMP) ;Symbols are obviously not eqv? unless eq?
  (je 'prim_ass_loop)
  (mov (@ 4 VAL) TEMP)
  (cmp (@ 4 EXP) TEMP)
  (jne 'prim_ass_loop)
(: 'prim_ass_found)
  (mov (@ ARGL) VAL)
  (ret)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(new-primitive "assoc")
  (insure-more-args ARGL)
  (mov (@ ARGL) VAL)
  (push ARGL) ;for reuse when calling equal?.
  (mov (@ 4 ARGL) ARGL)
  (insure-one-last-arg ARGL)
  (mov (@ ARGL) ARGL)
  (jmp 'prim_assoc_begin)

(: 'prim_assoc_loop)
  (mov (@ 4 ARGL) ARGL)
(: 'prim_assoc_begin)
  (test ARGL ARGL)
  (jzl 'prim_assoc_false)
  (insure-object-is-pair ARGL)
  (mov (@ ARGL) EXP)
  (insure-object-is-pair EXP)
  (mov (@ EXP) EXP)
  (cmp EXP VAL)
  (je 'prim_assoc_found)
  (push ARGL)
  (mov (@ 4 SP) ARGL)
  (mov EXP (@ ARGL))
  (mov (@ 4 ARGL) TEMP)
  (mov VAL (@ TEMP))
  (push VAL)
  (call-prim "equal?")
  (mov VAL TEMP)
  (pop VAL)
  (pop ARGL)
  (cmp 'false TEMP)
  (je 'prim_assoc_loop)
(: 'prim_assoc_found)
  (add 4 SP)
  (mov (@ ARGL) VAL)
  (ret)

(: 'prim_assoc_false)
  (add 4 SP)
  (return-false)

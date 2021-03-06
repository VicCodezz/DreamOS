(define edit #f)
(define edit-rows vga-rows)
(let ()
  (define matthew-reverse -1)
  (define load-pregexp #t)
  (define yank-buffer #f)
  (define search-term "")
  (define last-chosen-char #\~)
  (define text '())
  (define dirty #f)
  (define file #f)
  (define row-map (make-vector (edit-rows) -1))
  (define screen-first-row 0)
  (define screen-last-row 0)
  (define cursor-row 0)
  (define cursor-col 0)
  (define quantity 0)
  (set! edit
    (lambda (f)
      (vga-clear)
      (read-char) ;To clear buffer
      (cond
        (f
         (set! file f)
         (set! text (read-file))
         (set! dirty #f)))
      (insure-file-rows)
      (set! screen-first-row 0)
      (set! cursor-row 0)
      (set! cursor-col 0)
      (set! quantity 0)
      (display-screen)
      (display-status 7 (string-append (number->string (length text)) " lines"))
      (interact)))
  (define (insure-file-rows)
    (if (null? text)
      (set! text '(""))))
  (define (read-file)
    (reverse
      (call-with-input-file file
        (lambda (i) (read-text i '())))))
  (define (read-text i t)
    (let ((s (read-chars i '())))
      (if s
        (read-text i (cons (list->string s) t))
        t)))
  (define (read-chars i chars)
    (let ((c (read-char i)))
      (cond
        ((eof-object? c)
         (if (null? chars)
           #f
           (reverse chars)))
        ((char=? c #\newline)
         (reverse chars))
        (else
         (read-chars i (cons c chars))))))
  (define (clear-to-bottom)
    (cond
      ((< (vga-position-y) (- (edit-rows) 1))
       (vga-clear-row)
       (newline)
       (clear-to-bottom))))
  (define (display-screen)
    (vga-set-position 0 0)
    (write-screen (list-tail text screen-first-row) 0)
    (clear-to-bottom))
  (define (display-screen-partial)
    (let* ((r (vector-ref row-map (- cursor-row screen-first-row)))
           (t (cursor-rows)))
      (vga-set-position r 0)
      (if (and (pair? t) (write-paragraph (car t)))
        (begin
          (vga-clear-row)
          (newline)
          (if (not (= (vector-ref row-map (+ 1 r))
            (vga-position-y)))
            (display-screen)))
        (display-screen))))
  (define (write-screen t r)
    (cond
      ((pair? t)
       (vector-set! row-map r (vga-position-y))
       (if (write-paragraph (car t))
         (begin
           (vga-clear-row)
           (newline)
           (set! screen-last-row (+ screen-first-row r))
           (write-screen (cdr t) (+ 1 r)))))))
  (define (write-paragraph p)
    (let
      ((n (- (edit-rows) (vga-position-y) 1))
       (r (quotient (string-length p) (vga-columns))))
      (if (>= r n)
        (begin
          (display-color-string p (* n (vga-columns)))
          #f)
        (begin
          (display-color-string p (string-length p))
          #t))))
  (define (cursor-screen-row)
    (vector-ref row-map 
      (- cursor-row screen-first-row)))
  (define (refresh-row)
    (vga-set-position (cursor-screen-row) 0)
    (write-paragraph (list-ref text cursor-row)))
  (define (cursor-rows)
    (list-tail text cursor-row))
  (define (delete-chars quantity)
    (define s (cursor-rows))
    (define (delete-chars-loop q)
      (cond
        ((positive? q)
         (delete-char s)
         (delete-chars-loop (- q 1)))))
    (delete-chars-loop quantity)
    (display-screen-partial)
    (display-cursor #t 1))
  (define (insure-cursor-in-line s)
    (let ((l (string-length s)))
      (if (>= cursor-col l)
        (set! cursor-col (max 0 (- l 1))))
      l))
  (define (delete-char s)
    (let ((l (insure-cursor-in-line (car s))))
      (if (not (negative? l))
        (begin
          (set! dirty #t)
          (if (= cursor-col l)
            (begin
              (set-car! s (substring (car s) 0 cursor-col)))
            (set-car! s
              (string-append
                (substring (car s) 0 cursor-col)
                (substring (car s) (+ 1 cursor-col) l))))))))
  (define (interact)
    (sys-echo #f)
    (display-cursor #f 1)
    (let ((c (sys-read-char)))
      (cond
        ((char-numeric? c)
         (set! quantity
           (+ (* 10 quantity)
              (- (char->integer c)
                 (char->integer #\0)))))
        (else
         (if (zero? quantity)
           (if (char=? c #\G)
             (set! quantity (length text))
             (set! quantity 1)))
         (case c
           ((#\j) (move (* matthew-reverse (- quantity)) 0))
           ((#\k) (move (* matthew-reverse quantity) 0))
           ((#\h) (move 0 (- quantity)))
           ((#\l) (move 0 quantity))
           ((#\x) (delete-chars quantity))
           ((#\d) (delete quantity))
           ((#\y) (yank quantity))
           ((#\p) (paste quantity))
           ((#\r) (replace))
           ((#\o) (open-line-after))
           ((#\i) (insert-mode))
           ((#\a) (append-mode))
           ((#\/) (search))
           ((#\G) (move-absolute (- quantity 1) 0))
           ((#\^) (move-absolute cursor-row 0))
           ((#\$) (move-absolute cursor-row (- (string-length (car (cursor-rows))) 1)))
           ((#\-) (set! matthew-reverse (- matthew-reverse)))
           ((#\:) (command)))
         (set! quantity 0))))
    (interact))
  (define (command)
    (let ((c (get-line ":"))
          (w #f)
          (exclaim #f)
          (q #f))
      (for-each
        (lambda (x)
          (case x
            ((#\w) (set! w #t))
            ((#\!) (set! exclaim #t))
            ((#\q) (set! q #t))))
        (string->list c))
      (if w (save))
      (if q
        (if (and dirty (not exclaim))
          (display-status #x47 "You have unsaved changes.  Use :q! to override")
          (edit-exit)))))
  (define (search)
    (find-next-match
      (get-search-term)
      (cursor-rows)
      cursor-row
      (+ 1 cursor-col)))
  (define (find-next-match t s y x)
    (cond
      ((pair? s)
       (let ((i (match-position t (car s) x)))
         (if i
           (move-absolute y i)
           (find-next-match t (cdr s) (+ y 1) 0))))
      (else (display-status #x47 "No more occurrences found."))))
  (define (match-position t s i)
    (if (> (+ i (string-length t)) (string-length s))
      #f
      (if (substring=? t s 0 i)
        i
        (match-position t s (+ i 1)))))
  (define (substring=? t s ti si)
    (if (= ti (string-length t))
      #t
      (if (char=? (string-ref t ti) (string-ref s si))
        (substring=? t s (+ 1 ti) (+ 1 si))
        #f)))
  (define (get-search-term)
    (let ((s (get-line "/")))
      (if (positive? (string-length s))
        (set! search-term s))
      search-term))
  (define (get-line prefix)
    (display-status 7 prefix)
    (sys-echo #t)
    (let ((s (read-string '())))
      (sys-echo #f)
      (display-screen)
      s))
  (define (read-string chars)
    (let ((c (read-char)))
      (cond
        ((char=? c #\newline)
         (list->string (reverse chars)))
        (else
         (read-string (cons c chars))))))
  (define (delete q)
    (let ((c (sys-read-char)))
      (case c
        ((#\d) (yank-lines q) (delete-lines q)))))
  (define (delete-lines q)
    (if (zero? cursor-row)
      (if (>= (length text) q)
        (begin
          (set! text (list-tail text q))
          (set! dirty #t)))
      (let ((s (list-tail text (- cursor-row 1))))
        (if (> (length s) q)
          (begin
            (set-cdr! s (list-tail s (+ 1 q)))
            (set! dirty #t)))))
    (insure-file-rows)
    (insure-cursor-in-file)
    (display-screen))
  (define (yank q)
    (let ((c (sys-read-char)))
      (case c
        ((#\y) (yank-lines q)))))
  (define (yank-lines q)
    (define (yank-lines-loop s a i)
      (cond
        ((positive? i)
         (yank-lines-loop
           (cdr s)
           (cons (car s) a)
           (- i 1)))
        (else a)))
    (set! yank-buffer
      (yank-lines-loop (cursor-rows) '() q)))
  (define (paste q)
    (cond
      ((positive? q)
       (paste-lines (cursor-rows) yank-buffer)
       (paste (- q 1)))
      (else (display-screen))))
  (define (paste-lines s c)
    (cond
      ((pair? c)
       (let ((i (cons (string-copy (car c)) (cdr s))))
         (set-cdr! s i)
         (set! dirty #t)
         (paste-lines s (cdr c))))))
  (define (replace)
    (let* ((s (list-ref text cursor-row))
           (l (insure-cursor-in-line s)))
      (cond
        ((positive? l)
         (let ((c (sys-read-char)))
           (cond
             (c
              (if (char=? c #\~)
                (set! c (choose-char)))
              (string-set! s cursor-col c)
              (set! dirty #t)))))))
    (display-screen))
  (define escape (integer->char 27))
  (define backspace (integer->char 8))
  (define (insert-mode)
    (display-status 7 "INSERT")
    (let ((s (cursor-rows)))
      (insure-cursor-in-line (car s))
      (insert-loop s)))
  (define (append-mode)
    (display-status 7 "APPEND")
    (set! cursor-col (+ 1 cursor-col))
    (let ((s (cursor-rows)))
      (if (> cursor-col (string-length (car s)))
        (set! cursor-col (string-length (car s))))
      (insert-loop s)))
  (define (insert-loop s)
    (display-screen-partial)
    (insure-cursor-visible)
    (display-cursor #f 0)
    (let ((c (sys-read-char)))
      (cond
        ((char=? c escape)
         (display-status 7)
         (set! cursor-col (max 0 (- cursor-col 1))))
        ((char=? c backspace)
         (insert-backspace s))
        ((char=? c #\newline)
         (insert-newline s))
        ((char=? c #\~)
         (let ((c (choose-char)))
           (display-screen)
           (if c
             (insert-char s c))))
        (else
         (insert-char s c)))))
  (define (insert-backspace s)
    (if (positive? cursor-col)
      (begin
        (set! cursor-col (- cursor-col 1))
        (set! dirty #t)
        (set-car! s
          (string-append
            (substring (car s) 0 cursor-col)
            (substring (car s)
              (+ 1 cursor-col)
              (string-length (car s)))))))
    (insert-loop s))
  (define (insert-char s c)
    (let ((p (car s)))
      (set-car! s
        (string-append
          (substring p 0 cursor-col)
          (string c)
          (substring p cursor-col (string-length p)))))
    (set! dirty #t)
    (set! cursor-col (+ 1 cursor-col))
    (insert-loop s))
  (define (insert-newline s)
    (let*
      ((p (car s))
       (rest
         (if (= cursor-col (string-length p))
           ""
           (substring p cursor-col (string-length p)))))
      (set-car! s (substring p 0 cursor-col))
      (set! s (insert-line-after s rest))
      (insert-loop s)))
  (define (insert-line-after s i)
    (let ((n (cons i (cdr s))))
      (set-cdr! s n)
      (set! dirty #t)
      (set! cursor-row (+ 1 cursor-row))
      (set! cursor-col 0)
      (display-screen)
      n))
  (define (open-line-after)
    (insert-line-after (cursor-rows) "")
    (display-status 7 "INSERT")
    (insert-loop (cursor-rows)))
  (define (move-absolute r c)
    (set! cursor-row r)
    (move 0 (- c cursor-col)))
  (define (edit-exit)
    (vga-scroll-up)
    (vga-set-position (- (edit-rows) 1) 0)
    (sys-echo #t)
    (vga-set-attribute 7)
    (exit))
  (define (row-count) (length text))
  (define (insure-cursor-visible)
    (cond
      ((< cursor-row screen-first-row)
       (set! screen-first-row cursor-row)
       (display-screen))
      ((> cursor-row screen-last-row)
       (set! screen-first-row
         (+ (- cursor-row screen-last-row) screen-first-row))
       (display-screen)
       (insure-cursor-visible)))
    (cond
      ((negative? cursor-col)
       (set! cursor-col 0))))
  (define (insure-cursor-in-file)
    (cond
      ((negative? cursor-row)
       (set! cursor-row 0))
      ((>= cursor-row (row-count))
       (set! cursor-row (- (row-count) 1)))))
  (define (move y x)
    (set! cursor-row (+ cursor-row y))
    (set! cursor-col (+ cursor-col x))
    (insure-cursor-in-file)
    (insure-cursor-visible)
    (display-cursor (not (zero? x)) 1))
  (define (display-cursor reset in-line)
    (let* ((r (cursor-screen-row))
           (l (- (string-length (list-ref text cursor-row)) in-line))
           (c (max 0 (min cursor-col l))))
      (if (and reset (> cursor-col c))
        (set! cursor-col c))
      (vga-set-position
        (+ r (quotient c (vga-columns)))
        (remainder c (vga-columns)))))
  (define (choose-char)
    (define (loop n)
      (cond
        ((< n 256)
         (vga-set-position (quotient n 16) (remainder n 16))
         (write-char (integer->char n))
         (loop (+ 1 n)))))
    (define x vga-position-x)
    (define y vga-position-y)
    (define (read-loop)
      (let ((c (sys-read-char)))
        (cond
         ((char=? c escape)
          #f)
         ((char=? c #\newline)
          (set! last-chosen-char
            (integer->char
              (+ (* (vga-position-y) 16)
                 (vga-position-x))))
          last-chosen-char)
         ((char=? c #\~)
          (set! last-chosen-char #\~)
          #\~)
         ((char=? c #\space) last-chosen-char)
         (else
          (case c
            ((#\h)
             (if (> (x) 0)
               (vga-set-position (y) (- (x) 1))))
            ((#\j)
             (if (> (y) 0)
               (vga-set-position (- (y) 1) (x))))
            ((#\k)
             (if (< (y) #x0f)
               (vga-set-position (+ 1 (y)) (x))))
            ((#\l)
             (if (< (x) #x0f)
               (vga-set-position (y) (+ 1 (x))))))
          (read-loop)))))
    (vga-clear)
    (vga-set-attribute 15)
    (loop 0)
    (vga-set-position 0 0)
    (read-loop))
  (define (save)
    (call-with-output-file file
      (lambda (o)
        (define emit-newline #f)
        (for-each
          (lambda (r)
            (if emit-newline
              (newline o)
              (set! emit-newline #t))
            (display r o))
          text)))
    (set! dirty #f)
    (display-status 7 file))
  (define (display-color-string x n)
    (define default 7)
    (define backslash #f)
    (define paren 12)
    (define proc 14)
    (define quot 13) ;Must not share color with others
    (define lit 9)
    (define apos 5)
    (define comment 3) ;Must not share color with others
    (define (loop i)
      (vga-set-attribute default)
      (cond
        ((< i n)
         (let ((c (string-ref x i)))
           (cond
             ((or (char<? c #\newline)
                  (char<? #\~ c)
                  (and (char<? #\newline c) (char<? c #\space)))
              (vga-set-attribute #x47))
             (backslash
              (set! backslash #f))
             ((= default quot)
              (case c
                ((#\")
                 (set! default 7))))
             ((not (= default comment))
              (case c
                ((#\\)
                 (set! backslash #t))
                ((#\;)
                 (set! default comment)
                 (vga-set-attribute comment))
                ((#\space)
                 (set! default 7))
                ((#\()
                 (set! default proc)
                 (vga-set-attribute paren))
                ((#\))
                 (set! default 7)
                 (vga-set-attribute paren))
                ((#\')
                 (set! default apos)
                 (vga-set-attribute apos))
                ((#\#)
                 (set! default lit)
                 (vga-set-attribute default))
                ((#\")
                 (set! default quot)
                 (vga-set-attribute default)))))
           (write-char c))
         (loop (+ i 1)))))
    (loop 0))
  (define (display-status c . x)
    (vga-set-position (- (edit-rows) 1) 0)
    (vga-clear-row)
    (vga-set-attribute c)
    (for-each display x)
    (vga-set-attribute 7)))
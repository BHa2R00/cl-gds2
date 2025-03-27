(in-package :cl-user)
(defpackage :cl-gds2
  (:use :common-lisp :ieee-floats)
  (:export
    read-gds
    write-gds
    ))
(defun rd-ux (s x end)
  (if (< x 2)
    (read-byte s nil end)
    (let ((b1 (rd-ux s (1- x) end))
          (b0 (rd-ux s (1- x) end)))
      (cond
        ((numberp b0)
         (let ((u 0))
           (setf (ldb (byte (ash 8 (- x 2)) (ash 8 (- x 2))) u) b1)
           (setf (ldb (byte (ash 8 (- x 2)) 0) u) b0)
           u))
        (t b0)))))
(defun wt-ux (s x u)
  (if (< x 2)
    (write-byte u s)
    (let ()
      (wt-ux s (1- x) (ldb (byte (ash 8 (- x 2)) (ash 8 (- x 2))) u))
      (wt-ux s (1- x) (ldb (byte (ash 8 (- x 2)) 0) u))
      )))
(defun rd-uxn (s x end words)
  (let ((l (list)))
    (dotimes (k words)
      (push (rd-ux s x end) l))
    (reverse l)))
(defun wt-uxn (s x l words)
  (let ((l1 l))
    (dotimes (k words)
      (if l1
        (wt-ux s x (pop l1))
        (wt-ux s x 0)
        ))
    l1))
(defun uint2char (n)
  (let ((c (code-char n)))
    (if (and 
          ;(char>= c #\Newline) 
          (char<= c #\~)
          ) c nil)))
(defun bytes2string (l) 
  (coerce 
    (remove-if #'null (mapcar #'uint2char l)) 
    'string))
(defun string2bytes (l) (mapcar #'char-code (coerce l 'list)))
(defun uint2int (u msb)
  (if (= 0 (ash u (- 0 msb)))
    u
    (- 0 (1+(logand (1-(ash 1 (1+ msb))) (lognot u))))))
(defun int2uint (i msb)
  (if (< i 0)
    (logand (1-(ash 1 (1+ msb))) (1+(lognot(abs i))))
    i))
(defun uvec2ivec (us msb) (map 'list (lambda (u) (uint2int u msb)) us))
(defun ivec2uvec (is msb) (map 'list (lambda (i) (int2uint i msb)) is))
(defun r642d (v)
  ;(format t ";r642d ~A " v)
  (if (= v 0) 0
	(let ((vs (logand (ash v -63) #x1))
        (ve (logand (ash v -56) #x7F))
        (r 0))
    (do ((vm (logand v #x00FFFFFFFFFFFFFF) (ash vm -1))
         (e (- (* (- (uint2int ve 63) 64) 4) 4) (+ e 1)))
      ((not(> (ash vm -52) 1))
       (let ()
         (setf ve (logand (+ e 1023) #x7FF))
         (setf r (logior 
                   (ash vs 63) 
                   (ash ve 52) 
                   (logand vm #x000FFFFFFFFFFFFF))))))
    (setf r (ieee-floats:decode-float64 (uint2int r 63)))
	  ;(format t "-> ~A~%" r)
	  r)))
(defun d2r64 (v)
  ;(format t ";d2r64 ~A " v)
  (if (= v 0) 0
	(let*((raw (ieee-floats:encode-float64 (float v)))
        (vs (logand (ash raw -63) #x1))
        (ve (logand (ash raw -52) #x7FF))
        (vm (logior (ash 1 52) (logand raw #x000FFFFFFFFFFFFF)))
        (shift (rem (+ ve 1) 4))
        (e (- ve 1023))
        (r 0))
    (setf vm (ash vm shift))
	  (setf e (+ e 4))
	  (setf e (- e shift))
	  (setf ve (logand (+ (/ e 4) 64) #x7F))
	  (setf r (logior 
              (ash vs 63) 
              (ash ve 56) 
              (logand vm #x00FFFFFFFFFFFFFF)))
	  ;(format t "-> ~A~%" r)
	  (int2uint r 63))))
(defstruct propvalue ascii)
(defstruct propattr i)
(defstruct datatype i)
(defstruct pathtype i)
(defstruct texttype i)
(defstruct boxtype i)
(defstruct width i)
(defstruct strng ascii)
(defstruct layer i)
(defstruct sname ascii)
(defstruct strans uvec)
(defstruct colrow uvec)
(defstruct presentation uvec)
(defstruct angle r64)
(defstruct mag r64)
(defstruct xy ivec)
(defstruct box 
  layer 
  strans angle xy       
  boxtype          
  propattr propvalue)
(defstruct text     
  layer strng
  strans angle xy mag 
  texttype presentation 
  propattr propvalue)
(defstruct asref     
  sname 
  strans angle xy colrow 
  propattr propvalue)
(defstruct sref     
  sname 
  strans angle xy 
  propattr propvalue)
(defstruct path     
  layer 
  strans angle xy width 
  datatype pathtype 
  propattr propvalue)
(defstruct boundary 
  layer 
  strans angle xy       
  (datatype (make-datatype :i 0))
  propattr propvalue)
(defstruct timestamp 
  (year   (nth 0 (cdddr(reverse(multiple-value-list(decode-universal-time(get-universal-time)))))))
  (month  (nth 1 (cdddr(reverse(multiple-value-list(decode-universal-time(get-universal-time)))))))
  (day    (nth 2 (cdddr(reverse(multiple-value-list(decode-universal-time(get-universal-time)))))))
  (hour   (nth 3 (cdddr(reverse(multiple-value-list(decode-universal-time(get-universal-time)))))))
  (minute (nth 4 (cdddr(reverse(multiple-value-list(decode-universal-time(get-universal-time)))))))
  (sec    (nth 5 (cdddr(reverse(multiple-value-list(decode-universal-time(get-universal-time))))))))
(defstruct endel)
(defstruct endstr)
(defstruct strname ascii)
(defstruct str 
  (times (list (make-timestamp) (make-timestamp)))
  name elms)
(defstruct units 
  (sizes '(0.001d0 1.0d-9)) 
  strs)
(defstruct generations 
  (copies 3))
(defstruct endlib)
(defstruct libname ascii)
(defstruct lib 
  (times (list (make-timestamp) (make-timestamp)))
  name elms)
(defstruct header 
  (version 5))
(defstruct gds 
  (header (make-header)) 
  libs)
(defun rdgdsrec (s end)
  (let*((bsz (rd-ux s 2 end))
        (idx (rd-ux s 2 end)))
    (if (and (numberp bsz) (numberp idx))
    (let ()
    (setf bsz (- bsz 4))
    (case idx
      (#x0002 (make-header :version (rd-ux s 2 end)))
      (#x0102
       (let*((mtime (make-timestamp
                      :year (rd-ux s 2 end)
                      :month (rd-ux s 2 end)
                      :day (rd-ux s 2 end)
                      :hour (rd-ux s 2 end)
                      :minute (rd-ux s 2 end)
                      :sec (rd-ux s 2 end)
                      ))
             (atime (make-timestamp
                      :year (rd-ux s 2 end)
                      :month (rd-ux s 2 end)
                      :day (rd-ux s 2 end)
                      :hour (rd-ux s 2 end)
                      :minute (rd-ux s 2 end)
                      :sec (rd-ux s 2 end)
                      ))
             (name (rdgdsrec s end))
             (l (list)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp end e)
              (endlib-p e))
            (setf l (reverse l)))
           ;(format t "lib: ~s~%" e)
           (push e l))
         (make-lib :times (list mtime atime) :name name :elms l)))
      (#x0400 (make-endlib))
      (#x0502
       (let*((mtime (make-timestamp
                      :year (rd-ux s 2 end)
                      :month (rd-ux s 2 end)
                      :day (rd-ux s 2 end)
                      :hour (rd-ux s 2 end)
                      :minute (rd-ux s 2 end)
                      :sec (rd-ux s 2 end)
                      ))
             (atime (make-timestamp
                      :year (rd-ux s 2 end)
                      :month (rd-ux s 2 end)
                      :day (rd-ux s 2 end)
                      :hour (rd-ux s 2 end)
                      :minute (rd-ux s 2 end)
                      :sec (rd-ux s 2 end)
                      ))
             (name (rdgdsrec s end))
             (l (list)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp end e)
              (endstr-p e))
            (let ()
              (setf l (reverse l))))
           ;(format t "str: ~s~%" e)
           (push e l))
         (make-str :times (list mtime atime) :name name :elms l)))
      (#x0700 (make-endstr))
      (#x0206 (make-libname :ascii (bytes2string(rd-uxn s 1 end bsz))))
      (#x0606 (make-strname :ascii (bytes2string(rd-uxn s 1 end bsz))))
      (#x0305
       (let*((sz1 (r642d(rd-ux s 4 end)))
             (sz2 (r642d(rd-ux s 4 end)))
             (l (list)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp end e)
              (endlib-p e))
            (setf l (reverse l)))
           ;(format t "lib: ~s~%" e)
           (push e l))
         (make-units :sizes (list sz1 sz2) :strs l)))
      (#x2202 (make-generations :copies (rd-ux s 2 end)))
      (#x0800
       (let ((r (make-boundary)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp e end)
              (endel-p e)))
           (cond
             ((layer-p e) (setf (boundary-layer r) e))
             ((strans-p e) (setf (boundary-strans r) e))
             ((angle-p e) (setf (boundary-angle r) e))
             ((xy-p e) (setf (boundary-xy r) e))
             ((datatype-p e) (setf (boundary-datatype r) e))
             ((propattr-p e) (setf (boundary-propattr r) e))
             ((propvalue-p e) (setf (boundary-propvalue r) e))
             ))
         r))
      (#x0900
       (let ((r (make-path)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp e end)
              (endel-p e)))
           (cond
             ((layer-p e) (setf (path-layer r) e))
             ((strans-p e) (setf (path-strans r) e))
             ((angle-p e) (setf (path-angle r) e))
             ((xy-p e) (setf (path-xy r) e))
             ((width-p e) (setf (path-width r) e))
             ((datatype-p e) (setf (path-datatype r) e))
             ((pathtype-p e) (setf (path-pathtype r) e))
             ((propattr-p e) (setf (path-propattr r) e))
             ((propvalue-p e) (setf (path-propvalue r) e))
             ))
         r))
      (#x0a00
       (let ((r (make-sref)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp e end)
              (endel-p e)))
           (cond
             ((sname-p e) (setf (sref-sname r) e))
             ((strans-p e) (setf (sref-strans r) e))
             ((angle-p e) (setf (sref-angle r) e))
             ((xy-p e) (setf (sref-xy r) e))
             ((propattr-p e) (setf (sref-propattr r) e))
             ((propvalue-p e) (setf (sref-propvalue r) e))
             ))
         r))
      (#x0b00
       (let ((r (make-asref)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp e end)
              (endel-p e)))
           (cond
             ((sname-p e) (setf (asref-sname r) e))
             ((strans-p e) (setf (asref-strans r) e))
             ((colrow-p e) (setf (asref-colrow r) e))
             ((angle-p e) (setf (asref-angle r) e))
             ((xy-p e) (setf (asref-xy r) e))
             ((propattr-p e) (setf (asref-propattr r) e))
             ((propvalue-p e) (setf (asref-propvalue r) e))
             ))
         r))
      (#x0c00
       (let ((r (make-text)))
         (do ((e (rdgdsrec s end) (rdgdsrec s end)))
           ((or
              (equalp e end)
              (endel-p e)))
           (cond
             ((layer-p e) (setf (text-layer r) e))
             ((strans-p e) (setf (text-strans r) e))
             ((angle-p e) (setf (text-angle r) e))
             ((xy-p e) (setf (text-xy r) e))
             ((strng-p e) (setf (text-strng r) e))
             ((mag-p e) (setf (text-mag r) e))
             ((texttype-p e) (setf (text-texttype r) e))
             ((presentation-p e) (setf (text-presentation r) e))
             ((propattr-p e) (setf (text-propattr r) e))
             ((propvalue-p e) (setf (text-propvalue r) e))
             ))
         r))
      (#x1206 (make-sname :ascii (bytes2string(rd-uxn s 1 end bsz))))
      (#x1906 (make-strng :ascii (bytes2string(rd-uxn s 1 end bsz))))
      (#x2c06 (make-propvalue :ascii (bytes2string(rd-uxn s 1 end bsz))))
      (#x1a01 (make-strans :uvec (rd-uxn s 2 end (ash bsz -1))))
      (#x1302 (make-colrow :uvec (rd-uxn s 2 end (ash bsz -1))))
      (#x1701 (make-presentation :uvec (rd-uxn s 2 end (ash bsz -1))))
      (#x1003 (make-xy :ivec (uvec2ivec (rd-uxn s 3 end (ash bsz -2)) 31)))
      (#x0f03 (make-width :i (uint2int (rd-ux s 3 end) 31)))
      (#x1c05 (make-angle :r64 (r642d(rd-ux s 4 end))))
      (#x1b05 (make-mag :r64 (r642d(rd-ux s 4 end))))
      (#x0d02 (make-layer :i (uint2int (rd-ux s 2 end) 15)))
      (#x0e02 (make-datatype :i (uint2int (rd-ux s 2 end) 15)))
      (#x2102 (make-pathtype :i (uint2int (rd-ux s 2 end) 15)))
      (#x1602 (make-texttype :i (uint2int (rd-ux s 2 end) 15)))
      (#x2e02 (make-boxtype :i (uint2int (rd-ux s 2 end) 15)))
      (#x2b02 (make-propattr :i (uint2int (rd-ux s 2 end) 15)))
      (#x1100 (make-endel))
      (t idx)))
    idx)))
(defun wtgdsrec (s r)
  (cond
    ((header-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0002)
       (wt-ux s bsz (header-version r))
       ))
    ((lib-p r)
     (let ((bsz (* 2 (+ 6 6))))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0102)
       (map 'list
            (lambda (ts)
              (if (timestamp-p ts)
                (let ()
                  (wt-ux s 2 (timestamp-year ts))
                  (wt-ux s 2 (timestamp-month ts))
                  (wt-ux s 2 (timestamp-day ts))
                  (wt-ux s 2 (timestamp-hour ts))
                  (wt-ux s 2 (timestamp-minute ts))
                  (wt-ux s 2 (timestamp-sec ts))
                  )))
            (lib-times r))
       (wtgdsrec s (lib-name r))
       (map 'list
            (lambda (e)
              (wtgdsrec s e))
            (lib-elms r))
       (wtgdsrec s (make-endlib))
       ))
    ((endlib-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0400)
       ))
    ((str-p r)
     (let ((bsz (* 2 (+ 6 6))))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0502)
       (map 'list
            (lambda (ts)
              (if (timestamp-p ts)
                (let ()
                  (wt-ux s 2 (timestamp-year ts))
                  (wt-ux s 2 (timestamp-month ts))
                  (wt-ux s 2 (timestamp-day ts))
                  (wt-ux s 2 (timestamp-hour ts))
                  (wt-ux s 2 (timestamp-minute ts))
                  (wt-ux s 2 (timestamp-sec ts))
                  )))
            (str-times r))
       (wtgdsrec s (str-name r))
       (map 'list
            (lambda (e)
              (wtgdsrec s e))
            (str-elms r))
       (wtgdsrec s (make-endstr))
       ))
    ((endstr-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0700)
       ))
    ((libname-p r)
     (let ((bsz (length (libname-ascii r))))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0206)
       (wt-uxn s 1 (string2bytes(libname-ascii r)) bsz)
       ))
    ((strname-p r)
     (let ((bsz (length (strname-ascii r))))
       (if (oddp bsz) (incf bsz))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0606)
       (wt-uxn s 1 (string2bytes(strname-ascii r)) bsz)
       ))
    ((units-p r)
     (let ((bsz (+ 8 8)))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0305)
       (map 'list
            (lambda (sz)
              (wt-ux s 4 (d2r64 sz))
              )
            (units-sizes r))
       (map 'list
            (lambda (str)
              (wtgdsrec s str)
              )
            (units-strs r))
       ))
    ((generations-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x2202)
       (wt-ux s bsz (generations-copies r))
       ))
    ((boundary-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0800)
       (if (boundary-layer r) (wtgdsrec s (boundary-layer r)))
       (if (boundary-strans r) (wtgdsrec s (boundary-strans r)))
       (if (boundary-angle r) (wtgdsrec s (boundary-angle r)))
       (if (boundary-datatype r) (wtgdsrec s (boundary-datatype r)))
       (if (boundary-xy r) (wtgdsrec s (boundary-xy r)))
       (if (boundary-propattr r) (wtgdsrec s (boundary-propattr r)))
       (if (boundary-propvalue r) (wtgdsrec s (boundary-propvalue r)))
       (wtgdsrec s (make-endel))
       ))
    ((path-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0900)
       (if (path-layer r) (wtgdsrec s (path-layer r)))
       (if (path-strans r) (wtgdsrec s (path-strans r)))
       (if (path-angle r) (wtgdsrec s (path-angle r)))
       (if (path-datatype r) (wtgdsrec s (path-datatype r)))
       (if (path-pathtype r) (wtgdsrec s (path-pathtype r)))
       (if (path-width r) (wtgdsrec s (path-width r)))
       (if (path-xy r) (wtgdsrec s (path-xy r)))
       (if (path-propattr r) (wtgdsrec s (path-propattr r)))
       (if (path-propvalue r) (wtgdsrec s (path-propvalue r)))
       (wtgdsrec s (make-endel))
       ))
    ((sref-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0a00)
       (if (sref-sname r) (wtgdsrec s (sref-sname r)))
       (if (sref-strans r) (wtgdsrec s (sref-strans r)))
       (if (sref-angle r) (wtgdsrec s (sref-angle r)))
       (if (sref-xy r) (wtgdsrec s (sref-xy r)))
       (if (sref-propattr r) (wtgdsrec s (sref-propattr r)))
       (if (sref-propvalue r) (wtgdsrec s (sref-propvalue r)))
       (wtgdsrec s (make-endel))
       ))
    ((asref-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0b00)
       (if (asref-sname r) (wtgdsrec s (asref-sname r)))
       (if (asref-strans r) (wtgdsrec s (asref-strans r)))
       (if (asref-colrow r) (wtgdsrec s (asref-colrow r)))
       (if (asref-angle r) (wtgdsrec s (asref-angle r)))
       (if (asref-xy r) (wtgdsrec s (asref-xy r)))
       (if (asref-propattr r) (wtgdsrec s (asref-propattr r)))
       (if (asref-propvalue r) (wtgdsrec s (asref-propvalue r)))
       (wtgdsrec s (make-endel))
       ))
    ((text-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0c00)
       (if (text-layer r) (wtgdsrec s (text-layer r)))
       (if (text-texttype r) (wtgdsrec s (text-texttype r)))
       (if (text-presentation r) (wtgdsrec s (text-presentation r)))
       (if (text-strans r) (wtgdsrec s (text-strans r)))
       (if (text-angle r) (wtgdsrec s (text-angle r)))
       (if (text-mag r) (wtgdsrec s (text-mag r)))
       (if (text-xy r) (wtgdsrec s (text-xy r)))
       (if (text-strng r) (wtgdsrec s (text-strng r)))
       (if (text-propattr r) (wtgdsrec s (text-propattr r)))
       (if (text-propvalue r) (wtgdsrec s (text-propvalue r)))
       (wtgdsrec s (make-endel))
       ))
    ((sname-p r)
     (let ((bsz (length (sname-ascii r))))
       (if (oddp bsz) (incf bsz))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x1206)
       (wt-uxn s 1 (string2bytes(sname-ascii r)) bsz)
       ))
    ((strng-p r)
     (let ((bsz (length (strng-ascii r))))
       (if (oddp bsz) (incf bsz))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x1906)
       (wt-uxn s 1 (string2bytes(strng-ascii r)) bsz)
       ))
    ((propvalue-p r)
     (let ((bsz (length (propvalue-ascii r))))
       (if (oddp bsz) (incf bsz))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x2c06)
       (wt-uxn s 1 (string2bytes(propvalue-ascii r)) bsz)
       ))
    ((strans-p r)
     (let ((sz (length (strans-uvec r))))
       (wt-ux s 2 (+ 4 (ash sz 1)))
       (wt-ux s 2 #x1a01)
       (wt-uxn s 2 (strans-uvec r) sz)
       ))
    ((colrow-p r)
     (let ((sz (length (colrow-uvec r))))
       (wt-ux s 2 (+ 4 (ash sz 1)))
       (wt-ux s 2 #x1302)
       (wt-uxn s 2 (colrow-uvec r) sz)
       ))
    ((presentation-p r)
     (let ((sz (length (presentation-uvec r))))
       (wt-ux s 2 (+ 4 (ash sz 1)))
       (wt-ux s 2 #x1701)
       (wt-uxn s 2 (presentation-uvec r) sz)
       ))
    ((xy-p r)
     (let ((sz (length (xy-ivec r))))
       (wt-ux s 2 (+ 4 (ash sz 2)))
       (wt-ux s 2 #x1003)
       (wt-uxn s 3 (ivec2uvec (xy-ivec r) 31) sz)
       ))
    ((width-p r)
     (let ((bsz 4))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0f03)
       (wt-ux s 3 (int2uint (width-i r) 31))
       ))
    ((angle-p r)
     (let ((bsz 8))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x1c05)
       (wt-ux s 4 (d2r64 (angle-r64 r)))
       ))
    ((mag-p r)
     (let ((bsz 8))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x1b05)
       (wt-ux s 4 (d2r64 (mag-r64 r)))
       ))
    ((layer-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0d02)
       (wt-ux s bsz (int2uint (layer-i r) 15))
       ))
    ((datatype-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x0e02)
       (wt-ux s bsz (int2uint (datatype-i r) 15))
       ))
    ((pathtype-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x2102)
       (wt-ux s bsz (int2uint (pathtype-i r) 15))
       ))
    ((texttype-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x1602)
       (wt-ux s bsz (int2uint (texttype-i r) 15))
       ))
    ((boxtype-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x2e02)
       (wt-ux s bsz (int2uint (boxtype-i r) 15))
       )) 
    ((propattr-p r)
     (let ((bsz 2))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x2b02)
       (wt-ux s bsz (int2uint (propattr-i r) 15))
       ))
    ((endel-p r)
     (let ((bsz 0))
       (wt-ux s 2 (+ 4 bsz))
       (wt-ux s 2 #x1100)
       ))
    ))
(defun read-gds (s)
  (let ((r (make-gds :libs (list))))
    (do ((e (rdgdsrec s 'end)
            (rdgdsrec s 'end)))
      ((equalp e 'end) r)
      (cond
        ((header-p e) (setf (gds-header r) e))
        ((lib-p e) (setf (gds-libs r) (append (gds-libs r) (list e))))
        ))))
(defun write-gds (s e)
  (wtgdsrec s (gds-header e))
  (map 'list (lambda (ei) (wtgdsrec s ei)) (gds-libs e)))

;;---------------------=={ Area Label }==---------------------;;
;;                                                            ;;
;;  Allows the user to label picked areas or objects and      ;;
;;  either display the area in an ACAD Table (if available),  ;;
;;  optionally using fields to link area numbers and objects; ;;
;;  or write it to file.                                      ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright ?2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Version 1.9    -    29-10-2011                            ;;
;;------------------------------------------------------------;;

(defun c:zzArea nil (AreaLabel 3))
(defun c:zzA nil (AreaLabel 3))
;; Areas to Text
(defun c:zzArea2Table nil (AreaLabel 1))
;; Areas to Table
(defun c:zzArea2File nil (AreaLabel 2))
					;���ϡVBA��,��VBA������Ϊacad.dvb���ŵ�AutoCAD��װĿ¼���Զ�����
(defun c:zzDcx ()
  (command "_-VBARUN" "vba_zzDcx")
)
;; Areas to File
;;------------------------------------------------------------;;

(defun AreaLabel (flag	   /	    *error*  _startundo	       _endundo
		  _centroid	    _text    _open    _select
		  _getobjectid	    _isannotative     acdoc    acspc
		  ap	   ar	    as	     cf	      cm       el
		  fd	   fl	    fo	     n	      of       om
		  p1	   pf	    pt	     sf	      st       t1
		  t2	   tb	    th	     ts	      tx       ucsxang
		  ucszdir
		 )

  ;;------------------------------------------------------------;;
  ;;                         Adjustments                        ;;
  ;;------------------------------------------------------------;;

  (setq	h1 "�� �� �� �� ͳ �� ��"
	;; Heading
	t1 "���"
	;; Number Title
	t2 "���"
	;; Area Title
	pf ""
	;; Number Prefix (optional, "" if none)
	sf ""
	;; Number Suffix (optional, "" if none)
	ap ""
	;; Area Prefix (optional, "" if none)
	as ""
	;; Area Suffix (optional, "" if none)
	cf 1.0
	;; Area Conversion Factor (e.g. 1e-6 = mm2->m2)
	fd t
	;; Use fields to link numbers/objects to table (t=yes, nil=no)
	fo "%lu6%qf1"
	   ;; Area field formatting
  )


  (if (= nil areaName)
    (setq areaName "")
  )
  ;;------------------------------------------------------------;;

  (defun *error* (msg)
    (if	cm
      (setvar 'CMDECHO cm)
    )
    (if	el
      (progn (entdel el) (setq el nil))
    )
    (if	acdoc
      (_EndUndo acdoc)
    )
    (if	(and of (eq 'FILE (type of)))
      (close of)
    )
    (if	(and Shell (not (vlax-object-released-p Shell)))
      (vlax-release-object Shell)
    )
    (if	(null (wcmatch (strcase msg) "*BREAK,*CANCEL*,*EXIT*"))
      (princ (strcat "\n--> Error: " msg))
    )
    (princ)
  )

  ;;------------------------------------------------------------;;

  (defun _StartUndo (doc)
    (_EndUndo doc)
    (vla-StartUndoMark doc)
  )

  ;;------------------------------------------------------------;;

  (defun _EndUndo (doc)
    (if	(= 8 (logand 8 (getvar 'UNDOCTL)))
      (vla-EndUndoMark doc)
    )
  )

  ;;------------------------------------------------------------;;

  (defun _centroid (space objs / reg cen)
    (setq reg (car (vlax-invoke space 'addregion objs))
	  cen (vlax-get reg 'centroid)
    )
    (vla-delete reg)
    (trans cen 1 0)
  )

  ;;------------------------------------------------------------;;

  (defun _text (space point string height rotation / text)
    (setq text (vla-addtext space string (vlax-3D-point point) height))
    (vla-put-alignment text acalignmentmiddlecenter)
    (vla-put-textalignmentpoint text (vlax-3D-point point))
    (vla-put-rotation text rotation)
    text
  )

  ;;------------------------------------------------------------;;

  (defun _Open (target / Shell result)
    (if	(setq Shell (vla-getInterfaceObject
		      (vlax-get-acad-object)
		      "Shell.Application"
		    )
	)
      (progn
	(setq result
	       (and
		 (or (eq 'INT (type target)) (setq target (findfile target)))
		 (not
		   (vl-catch-all-error-p
		     (vl-catch-all-apply
		       'vlax-invoke
		       (list Shell 'Open target)
		     )
		   )
		 )
	       )
	)
	(vlax-release-object Shell)
      )
    )
    result
  )

  ;;------------------------------------------------------------;;

  (defun _Select (msg pred func init / e)
    (setq pred (eval pred))
    (while
      (progn (setvar 'ERRNO 0)
	     (apply 'initget init)
	     (setq e (func msg))
	     (cond
	       ((= 7 (getvar 'ERRNO))
		(princ "\nMissed, try again.")
	       )
	       ((eq 'STR (type e))
		nil
	       )
	       ((vl-consp e)
		(if (and pred (not (pred (setq e (car e)))))
		  (princ "\nInvalid Object Selected.")
		)
	       )
	     )
      )
    )
    e
  )

  ;;------------------------------------------------------------;;

  (defun _GetObjectID (doc obj)
    (if	(vl-string-search "64" (getenv "PROCESSOR_ARCHITECTURE"))
      (vlax-invoke-method
	(vla-get-Utility doc)
	'GetObjectIdString
	obj
	:vlax-false
      )
      (itoa (vla-get-Objectid obj))
    )
  )

  ;;------------------------------------------------------------;;

  (defun _isAnnotative (style / object annotx)
    (and
      (setq object (tblobjname "STYLE" style))
      (setq
	annotx (cadr (assoc -3 (entget object '("AcadAnnotative"))))
      )
      (= 1 (cdr (assoc 1070 (reverse annotx))))
    )
  )

  ;;------------------------------------------------------------;;

  (setq	acdoc	(vla-get-activedocument (vlax-get-acad-object))
	acspc	(vlax-get-property
		  acdoc
		  (if (= 1 (getvar 'CVPORT))
		    'Paperspace
		    'Modelspace
		  )
		)

	ucszdir	(trans '(0. 0. 1.) 1 0 t)
	ucsxang	(angle '(0. 0. 0.) (trans (getvar 'UCSXDIR) 0 ucszdir))
  )
  (_StartUndo acdoc)
  (setq cm (getvar 'CMDECHO))
  (setvar 'CMDECHO 0)
  (setq	om (eq "1"
	       (cond ((getenv "LMAC_AreaLabel"))
		     ((setenv "LMAC_AreaLabel" "0"))
	       )
	   )
  )

  (setq	ts
	 (/ (getvar 'TEXTSIZE)
	    (if	(_isAnnotative (getvar 'TEXTSTYLE))
	      (cond ((getvar 'CANNOSCALEVALUE))
		    (1.0)
	      )
	      1.0
	    )
	 )
  )

  (cond
    ((not (vlax-method-applicable-p acspc 'addtable))

     (princ "\n--> Table Objects not Available in this Version.")
    )
    ((=	4
	(logand	4
		(cdr (assoc 70 (tblsearch "LAYER" (getvar 'CLAYER))))
	)
     )

     (princ "\n--> Current Layer Locked.")
    )
    ((not
       (setq *al:num
	      (cond
		((= flag 3) 1)
		(
		 (getint
		   (strcat "\n��������ʼֵ <"
			   (itoa (setq *al:num (1+ (cond (*al:num)
							 (0)
						   )
					       )
				 )
			   )
			   ">: "
		   )
		 )
		)
		(*al:num)
	      )
       )
     )
    )
    ((= flag 1)

     (setq th
	    (* 2.
	       (if
		 (zerop
		   (setq th
			  (vla-gettextheight
			    (setq st
				   (vla-item
				     (vla-item
				       (vla-get-dictionaries acdoc)
				       "ACAD_TABLESTYLE"
				     )
				     (getvar 'CTABLESTYLE)
				   )
			    )
			    acdatarow
			  )
		   )
		 )
		  ts
		  (/ th
		     (if (_isAnnotative (vla-gettextstyle st acdatarow))
		       (cond ((getvar 'CANNOSCALEVALUE))
			     (1.0)
		       )
		       1.0
		     )
		  )
	       )
	    )
     )

     (if
       (cond
	 (
	  (progn (initget "Add")
		 (vl-consp (setq pt
				  (getpoint "\n�������������λ�� <ѡ�����������>: "
				  )
			   )
		 )
	  )
	  (setq	tb
		 (vla-addtable
		   acspc
		   (vlax-3D-point (trans pt 1 0))
		   2
		   2
		   th
		   (* 1.5 th (max (strlen t1) (strlen t2)))
					;�������������
		 )
	  )
	  (vla-put-direction tb (vlax-3D-point (getvar 'UCSXDIR)))
	  (vla-settext tb 0 0 h1)
	  (vla-settext tb 1 0 t1)
	  (vla-settext tb 1 1 t2)

	  (while
	    (progn
	      (if om
		(setq p1
		       (_Select
			 (strcat "\nѡ����һ������[ʰ��]<�˳�>: ")
			 '(lambda (x)
			    (and
			      (vlax-property-available-p
				(vlax-ename->vla-object x)
				'area
			      )
			      (not (eq "HATCH" (cdr (assoc 0 (entget x)))))
			      (or (eq "REGION" (cdr (assoc 0 (entget x))))
				  (vlax-curve-isclosed x)
			      )
			    )
			  )
			 entsel
			 '("Pick")
		       )
		)
		(progn (initget "Object")
		       (setq p1 (getpoint "\nѡ������[����]<�˳�>: "))
		)
	      )
	      (cond
		((null p1)

		 (vla-delete tb)
		)
		((eq "Pick" p1)

		 (setq om nil)
		 t
		)
		((eq "Object" p1)

		 (setq om t)
		)
		((eq 'ENAME (type p1))

		 (setq tx
			(cons
			  (_text acspc
				 (_centroid
				   acspc
				   (list (setq p1 (vlax-ename->vla-object p1)))
				 )
				 (strcat pf (itoa *al:num) sf)
				 ts
				 ucsxang
			  )
			  tx
			)
		 )
		 (vla-insertrows tb (setq n 2) th 1)
		 (vla-settext
		   tb
		   n
		   1
		   (if fd
		     (strcat "%<\\AcObjProp Object(%<\\_ObjId "
			     (_GetObjectID acdoc p1)
			     ">%).Area \\f \""
			     fo
			     "\">%"
		     )
		     (strcat ap (rtos (* cf (vla-get-area p1)) 2 2) as)
		   )
		 )
		 (vla-settext
		   tb
		   n
		   0
		   (if fd
		     (strcat "%<\\AcObjProp Object(%<\\_ObjId "
			     (_GetObjectID acdoc (car tx))
			     ">%).TextString>%"
		     )
		     (strcat pf (itoa *al:num) sf)
		   )
		 )
		 nil
		)
		((vl-consp p1)

		 (setq el (entlast))
		 (vl-cmdf "_.-boundary"	    "_A"     "_I"     "_N"
			  ""	   "_O"	    "_P"     ""	      "_non"
			  p1	   ""
			 )

		 (if (not (equal el (setq el (entlast))))
		   (progn
		     (setq tx
			    (cons
			      (_text
				acspc
				(_centroid acspc
					   (list (vlax-ename->vla-object el))
				)
				(strcat pf (itoa *al:num) sf)
				ts
				ucsxang
			      )
			      tx
			    )
		     )
		     (vla-insertrows tb (setq n 2) th 1)
		     (vla-settext
		       tb
		       n
		       1
		       (strcat ap
			       (rtos (* cf (vlax-curve-getarea el)) 2 2)
			       as
		       )
		     )
		     (vla-settext
		       tb
		       n
		       0
		       (if fd
			 (strcat "%<\\AcObjProp Object(%<\\_ObjId "
				 (_GetObjectID acdoc (car tx))
				 ">%).TextString>%"
			 )
			 (strcat pf (itoa *al:num) sf)
		       )
		     )
		     (redraw el 3)
		     nil
		   )
		   (vla-delete tb)
		 )
		)
	      )
	    )
	  )
	  (not (vlax-erased-p tb))
	 )
	 (
	  (and
	    (setq tb
		   (_Select "\nѡ�����б����: "
			    '(lambda (x)
			       (eq "ACAD_TABLE" (cdr (assoc 0 (entget x))))
			     )
			    entsel
			    nil
		   )
	    )
	    (< 1
	       (vla-get-columns (setq tb (vlax-ename->vla-object tb)))
	    )
	  )
	  (setq	n	(1- (vla-get-rows tb))
		*al:num	(1- *al:num)
	  )
	 )
       )
	(progn
	  (while
	    (if	om
	      (setq p1
		     (_Select (strcat "\nSelect Object ["
				      (if tx
					"Undo/"
					""
				      )
				      "Pick] <Exit>: "
			      )
			      '(lambda (x)
				 (and
				   (vlax-property-available-p
				     (vlax-ename->vla-object x)
				     'area
				   )
				   (not (eq "HATCH" (cdr (assoc 0 (entget x)))))
				   (or (eq "REGION" (cdr (assoc 0 (entget x))))
				       (vlax-curve-isclosed x)
				   )
				 )
			       )
			      entsel
			      (list (if	tx
				      "Undo Pick"
				      "Pick"
				    )
			      )
		     )
	      )
	      (progn (initget (if tx
				"Undo Object"
				"Object"
			      )
		     )
		     (setq p1 (getpoint	(strcat	"\nѡ������["
						(if tx
						  "Undo/"
						  ""
						)
						"Object] <Exit>: "
					)
			      )
		     )
	      )
	    )
	     (cond
	       ((and tx (eq "Undo" p1))

		(if el
		  (progn (entdel el) (setq el nil))
		)
		(vla-deleterows tb n 1)
		(vla-delete (car tx))
		(setq n	      (1- n)
		      tx      (cdr tx)
		      *al:num (1- *al:num)
		)
	       )
	       ((eq "Undo" p1)

		(princ "\n--> ɶҲû��.")
	       )
	       ((eq "Object" p1)

		(if el
		  (progn (entdel el) (setq el nil))
		)
		(setq om t)
	       )
	       ((eq "Pick" p1)

		(setq om nil)
	       )
	       ((and om (eq 'ENAME (type p1)))

		(setq tx
		       (cons
			 (_text	acspc
				(_centroid
				  acspc
				  (list (setq p1 (vlax-ename->vla-object p1)))
				)
				(strcat pf (itoa (setq *al:num (1+ *al:num))) sf)
				ts
				ucsxang
			 )
			 tx
		       )
		)
		(vla-insertrows tb (setq n (1+ n)) th 1)
		(vla-settext
		  tb
		  n
		  1
		  (if fd
		    (strcat "%<\\AcObjProp Object(%<\\_ObjId "
			    (_GetObjectID acdoc p1)
			    ">%).Area \\f \""
			    fo
			    "\">%"
		    )
		    (strcat ap (rtos (* cf (vla-get-area p1)) 2 2) as)
		  )
		)
		(vla-settext
		  tb
		  n
		  0
		  (if fd
		    (strcat "%<\\AcObjProp Object(%<\\_ObjId "
			    (_GetObjectID acdoc (car tx))
			    ">%).TextString>%"
		    )
		    (strcat pf (itoa *al:num) sf)
		  )
		)
	       )
	       ((vl-consp p1)

		(if el
		  (progn (entdel el) (setq el nil))
		)
		(setq el (entlast))
		(vl-cmdf "_.-boundary"	   "_A"	    "_I"     "_N"
			 ""	  "_O"	   "_P"	    ""	     "_non"
			 p1	  ""
			)

		(if (not (equal el (setq el (entlast))))
		  (progn
		    (setq tx
			   (cons
			     (_text
			       acspc
			       (_centroid acspc
					  (list (vlax-ename->vla-object el))
			       )
			       (strcat pf (itoa (setq *al:num (1+ *al:num))) sf)
			       ts
			       ucsxang
			     )
			     tx
			   )
		    )
		    (vla-insertrows tb (setq n (1+ n)) th 1)
		    (vla-settext
		      tb
		      n
		      1
		      (strcat ap
			      (rtos (* cf (vlax-curve-getarea el)) 2 2)
			      as
		      )
		    )
		    (vla-settext
		      tb
		      n
		      0
		      (if fd
			(strcat	"%<\\AcObjProp Object(%<\\_ObjId "
				(_GetObjectID acdoc (car tx))
				">%).TextString>%"
			)
			(strcat pf (itoa *al:num) sf)
		      )
		    )
		    (redraw el 3)
		  )
		  (princ "\n--> Error Retrieving Area.")
		)
	       )
	     )
	  )
	  (if el
	    (progn (entdel el) (setq el nil))
	  )
	)
     )
    )
    ((= flag 2)
     (and
       (setq fl	(getfiled "�������ͳ���ļ�"
			  (cond	(*file*)
				("")
			  )
			  "txt;csv;xls"
			  1
		)
       )
       (setq of (open fl "w"))
     )
     (setq *file*  (vl-filename-directory fl)
	   de	   (cdr
		     (assoc (strcase (vl-filename-extension fl) t)
			    '((".txt" . "\t") (".csv" . ",") (".xls" . "\t"))
		     )
		   )
	   *al:num (1- *al:num)
     )
     (write-line h1 of)
     (write-line (strcat t1 de t2) of)

     (while
       (if om
	 (setq p1
		(_Select (strcat "\nѡ�����[ʰȡ]<�˳�>: ")
			 '(lambda (x)
			    (and
			      (vlax-property-available-p
				(vlax-ename->vla-object x)
				'area
			      )
			      (not (eq "HATCH" (cdr (assoc 0 (entget x)))))
			      (or (eq "REGION" (cdr (assoc 0 (entget x))))
				  (vlax-curve-isclosed x)
			      )
			    )
			  )
			 entsel
			 '("Pick")
		)
	 )
	 (progn
	   (initget "Object")
	   (setq p1 (getpoint (strcat "\nѡ������[����]<�˳�>: ")))
	 )
       )
	(cond
	  ((eq "Object" p1)

	   (if el
	     (progn (entdel el) (setq el nil))
	   )
	   (setq om t)
	  )
	  ((eq "Pick" p1)

	   (setq om nil)
	  )
	  ((eq 'ENAME (type p1))

	   (_text
	     acspc
	     (_centroid	acspc
			(list (setq p1 (vlax-ename->vla-object p1)))
	     )
	     (strcat pf (itoa (setq *al:num (1+ *al:num))) sf)
	     ts
	     ucsxang
	   )
	   (write-line
	     (strcat pf
		     (itoa *al:num)
		     sf
		     de
		     ap
		     (rtos (* cf (vla-get-area p1)) 2)
		     as
	     )
	     of
	   )
	  )
	  ((vl-consp p1)

	   (if el
	     (progn (entdel el) (setq el nil))
	   )
	   (setq el (entlast))
	   (vl-cmdf "_.-boundary"     "_A"     "_I"	"_N"
		    ""	     "_O"     "_P"     ""	"_non"
		    p1	     ""
		   )

	   (if (not (equal el (setq el (entlast))))
	     (progn
	       (_text
		 acspc
		 (_centroid acspc (list (vlax-ename->vla-object el)))
		 (strcat pf (itoa (setq *al:num (1+ *al:num))) sf)
		 ts
		 ucsxang
	       )
	       (write-line
		 (strcat pf
			 (itoa *al:num)
			 sf
			 de
			 ap
			 (rtos (* cf (vlax-curve-getarea el)) 2 2)
			 as
		 )
		 of
	       )
	       (redraw el 3)
	     )
	     (princ "\n--> Error Retrieving Area.")
	   )
	  )
	)
     )
     (if el
       (progn (entdel el) (setq el nil))
     )
     (setq of (close of))
     (_Open (findfile fl))
    )
    ((= flag 3)
					;Ϊ���ָ����Ż����ƣ��Ա��뷽�����Ӧ
					;(setq areaName
					;      (cond
					;	(
					;	 (getstring  (strcat "\n������ <\042" areaName  "\042>: " ) )
					;	)
					; 	 (areaName)
					;    )
					;       )
     (princ
       "���ܣ���ע�������������(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
     )
     (if (= areaName "zz")
       (setq areaName "")
     )
     (setq areaName_old areaName)
     (setq areaName
	    (getstring (strcat "\n������ <\042" areaName "\042>: ")
	    )
     )
     (if (= areaName "")
       (setq areaName areaName_old)
     )


     (while
       (if om
	 (setq p1
		(_Select (strcat "\nѡ�����[ʰȡ]<�˳�>: ")
			 '(lambda (x)
			    (and
			      (vlax-property-available-p
				(vlax-ename->vla-object x)
				'area
			      )
			      (not (eq "HATCH" (cdr (assoc 0 (entget x)))))
			      (or (eq "REGION" (cdr (assoc 0 (entget x))))
				  (vlax-curve-isclosed x)
			      )
			    )
			  )
			 entsel
			 '("Pick")
		)
	 )
	 (progn
	   (initget "Object")
	   (setq p1 (getpoint (strcat "\nѡ������<�˳�>: ")))
	 )
       )
	(cond
	  ((eq "Object" p1)

	   (if el
	     (progn (entdel el) (setq el nil))
	   )
	   (setq om t)
	  )
	  ((eq "Pick" p1)

	   (setq om nil)
	  )
	  ((eq 'ENAME (type p1))

	   (_text
	     acspc
	     (_centroid	acspc
			(list (setq p1 (vlax-ename->vla-object p1)))
	     )
	     (strcat pf (rtos (* cf (vla-get-area p1)) 2) sf)
	     ts
	     ucsxang
	   )
	  )
	  ((vl-consp p1)
	   (setq el (entlast))
	   (vl-cmdf "_.-boundary"     "_A"     "_I"	"_N"
		    ""	     "_O"     "_P"     ""	"_non"
		    p1	     ""
		   )

	   (if (not (equal el (setq el (entlast))))
	     (progn
	       (_text
		 acspc
		 (_centroid acspc (list (vlax-ename->vla-object el)))
		 (strcat (if (and (/= areaName "zz") (/= areaName ""))
			   (strcat areaName ":")
			   (strcat "" "")
			 )
			 (rtos (* cf (vlax-curve-getarea el)) 2 2)
			 sf
		 )
		 ts
		 ucsxang
	       )
	       (redraw el 1)
	     )
	     (princ "\n--> Error Retrieving Area.")
	   )
	  )
	)
     )
    )
  )
  (setenv "LMAC_AreaLabel"
	  (if om
	    "1"
	    "0"
	  )
  )
  (setvar 'CMDECHO cm)
  (_EndUndo acdoc)
  (princ)
)

;;���ɷ����������ļ�------------------------------------------------------------;;
;;;��ģ
(defun mod (numA numB)
  (- (/ (* 1.0 numA) (* numB 1.0))
     (fix (/ (* numA 1.0) (* 1.0 numB)))
  )
)

(defun C:zzFGW (/	  mscale    gridDistCm		pointId
		datFile	  pointA    pointB    pA	pB
		gridDist  zx_x	    zx_y      zs_x	zs_y
		fileId	  gridPointX	      gridPointY
	       )
  (princ
    "���ܣ����ɵ���ͼ�����������ļ���(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
  )

  (setq	mscale
	 (getint "�������ͼ�����߷�ĸ(100/200/500/1000/2000/5000)��"
	 )
  )
  (while (or (/= (mod mscale 100) 0) (<= mscale 0))
    (setq mscale
	   (getint "�������ͼ�����߷�ĸ100/200/500/1000/2000/5000��")
    )
  )

;;;(setq gridDistCm (getint "�������������(cm):"))
  (setq gridDistCm 10)
;;;Ĭ��10cm
  (setq pointId 0)
;;;(setq	datFile
;;; (getfiled "��������������ļ�����"
;;;	   (cond (*file*)
;;;		 ("")
;;;	   )
;;;	   "dat"
;;;	   1
;;;)
;;;)
  (setq datFile "D:\\����ͼ���귽��������.dat")

  (setq pointA (getpoint "�������һ�㣺"))
  (princ (strcat "N:"
		 (rtos (cadr pointA) 2 3)
		 " E:"
		 (rtos (car pointA) 2 3)
		 "\n"
	 )
  )
  (setq pointB (getpoint "������ڶ��㣺"))
  (princ (strcat "N:"
		 (rtos (cadr pointB) 2 3)
		 " E:"
		 (rtos (car pointB) 2 3)
		 "\n"
	 )
  )
  (setq	pA pointA
	pB pointB
  )
  (setq	pointA (list (min (car pA) (car pB))
		     (min (cadr pA) (cadr pB))
	       )
  )

  (setq	pointB (list (max (car pA) (car pB))
		     (max (cadr pA) (cadr pB))
	       )
  )
;;;�������룺��
  (setq gridDist (* (/ mscale 100) gridDistCm))
  (setq zx_x (* (+ (fix (/ (car pointA) gridDist)) 1) gridDist))
  (setq zx_y (* (+ (fix (/ (cadr pointA) gridDist)) 1) gridDist))

  (setq zs_x (* (fix (/ (car pointB) gridDist)) gridDist))
  (setq zs_y (* (fix (/ (cadr pointB) gridDist)) gridDist))

  (setq gridPointX zx_x)

  (setq fileId (open datFile "w"))
  (while (<= gridPointX zs_x)
    (setq gridPointY zx_y)
    (while (<= gridPointY zs_y)
      (setq pointId (+ pointId 1))
      (write-line
	(strcat	(itoa pointId)
		",+,"
		(itoa gridPointX)
		","
		(itoa gridPointY)
		",0.0"
	)
	fileId
      )
      (setq pointId (+ pointId 1))
      (write-line
	(strcat	(itoa pointId)
		",NE,"
		(itoa gridPointX)
		","
		(itoa gridPointY)
		",0.0"
	)
	fileId
      )

      '(command "_point" (list gridPointX gridPointY))
      (setq gridPointY (+ gridPointY gridDist))
    )
;;;end while y

    (setq gridPointX (+ gridPointX gridDist))
  )
;;;end while x

  (setq fileId (close fileId))
  (princ)
)
;;���ɷ����������ļ�------------------------------------------------------------;;
;;��ȡָ�������ڵĵ㣬ɾ����������ε�------------------------------------------------------------;;
(defun C:zzQydx
       (/ ptName ptSign ptE ptN ptH ptCount filename1 filename2)
  (princ
    "���ܣ�ɾ��ָ��������ĵ㡣(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
  )
  (setq	filename1
	 (getfiled "��ʾ�ַ���"
		   "D:\\"
		   "dat"
		   2
	 )
  )
  (if filename1
    (progn
      (setq
	filename2 (strcat (car (splitx filename1 ".dat"))
			  "-������ȡ-"
			  (date)
			  "-"
			  (time)
			  ".dat"
		  )
      )
      (setq regionObj (entsel))
      (setq f1 (open filename1 "r"))
      (if (and f1 regionObj)
	(progn
	  (setq f2 (open filename2 "w"))
	  (setq rIndex 0)
	  (setq ptCount 0)
	  (while (setq lineStr (read-line f1))
	    (setq lineStrs (splitX lineStr ","))
	    (setq ptName (cons (nth 0 lineStrs) ptName))
	    ;;�����Ż�������ɱ�
	    (setq ptE (cons (nth 2 lineStrs) ptE))
	    ;;��E���ɱ�
	    (setq ptN (cons (nth 3 lineStrs) ptN))
	    ;;��N���ɱ�
	    (setq ptH (cons (nth 4 lineStrs) ptH))
	    ;;��H���ɱ�
	    (setq ptSign (cons (itoa rIndex) ptSign))
	    ;;���ɼǺű�
	    (setq rIndex (+ rIndex 1))
	  )
	  (setq ptName (reverse ptName))
	  ;;����
	  (setq ptSign (reverse ptSign))
	  ;;����
	  (setq ptE (reverse ptE))
	  ;;����
	  (setq ptN (reverse ptN))
	  ;;����
	  (setq ptH (reverse ptH))
	  ;;����
	  (close f1)
	  ;;����
	  (setq rIndex 0)
	  (while (setq tmpPtname (nth rIndex ptName))
	    (setq tmpE (nth rIndex ptE))
	    (setq tmpN (nth rIndex ptN))
	    (setq tmpH (nth rIndex ptH))
	    (setq tmpSign (nth rIndex ptSign))
	    (if	(pt_inorout regionObj (list (atof tmpE) (atof tmpN)))
	      (progn
		(write-line
		  (strcat tmpPtname ",," tmpE "," tmpN "," tmpH)
		  f2
		)
		(setq ptCount (+ 1 ptCount))
	      )
	    )
	    (setq rIndex (+ rIndex 1))
	  )
	  ;;����
	  (princ
	    (strcat
	      "����ȡ"
	      (itoa ptCount)
	      "���㡣(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
	    )
	  )
	  ;;(princ "\n")
	  (close f2)
	)
	;;End progn
	(princ
	  "�û�ȡ��������(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
	)
      )
      ;;end if

    )
    ;; end progn1
    (princ
      "�û�ȡ��������(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
    )
  )
  ;;end if1
  (princ)
)
;;��ȡָ�������ڵĵ㣬ɾ����������ε�------------------------------------------------------------;;

;;��������ε������ļ���ɾ�������ڵ��ε�------------------------------------------------------------;;
(defun C:zzQywdx
       (/ ptName ptSign ptE ptN ptH ptCount filename1 filename2)
  (princ
    "���ܣ�ɾ��ָ�������ڵĵ㣬ȡ������ĵ��ε㡣(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
  )
  (setq	filename1
	 (getfiled "��ʾ�ַ���"
		   "D:\\"
		   "dat"
		   2
	 )
  )
  (if filename1
    (progn
      (setq
	filename2 (strcat (car (splitx filename1 ".dat"))
			  "-��������ȡ-"
			  (date)
			  "-"
			  (time)
			  ".dat"
		  )
      )
      (setq regionObj (entsel))
      (setq f1 (open filename1 "r"))
      (if (and f1 regionObj)
	(progn
	  (setq f2 (open filename2 "w"))
	  (setq rIndex 0)
	  (setq ptCount 0)
	  (while (setq lineStr (read-line f1))
	    (setq lineStrs (splitX lineStr ","))
	    (setq ptName (cons (nth 0 lineStrs) ptName))
	    ;;�����Ż�������ɱ�
	    (setq ptE (cons (nth 2 lineStrs) ptE))
	    ;;��E���ɱ�
	    (setq ptN (cons (nth 3 lineStrs) ptN))
	    ;;��N���ɱ�
	    (setq ptH (cons (nth 4 lineStrs) ptH))
	    ;;��H���ɱ�
	    (setq ptSign (cons (itoa rIndex) ptSign))
	    ;;���ɼǺű�
	    (setq rIndex (+ rIndex 1))
	  )
	  (setq ptName (reverse ptName))
	  ;;����
	  (setq ptSign (reverse ptSign))
	  ;;����
	  (setq ptE (reverse ptE))
	  ;;����
	  (setq ptN (reverse ptN))
	  ;;����
	  (setq ptH (reverse ptH))
	  ;;����
	  (close f1)
	  ;;����
	  (setq rIndex 0)
	  (while (setq tmpPtname (nth rIndex ptName))
	    (setq tmpE (nth rIndex ptE))
	    (setq tmpN (nth rIndex ptN))
	    (setq tmpH (nth rIndex ptH))
	    (setq tmpSign (nth rIndex ptSign))
	    (if
	      (not (pt_inorout regionObj (list (atof tmpE) (atof tmpN)))
	      )
	       (progn
		 (write-line
		   (strcat tmpPtname ",," tmpE "," tmpN "," tmpH)
		   f2
		 )
		 (setq ptCount (+ 1 ptCount))
	       )
	    )
	    (setq rIndex (+ rIndex 1))
	  )
	  ;;����
	  (princ
	    (strcat
	      "����ȡ"
	      (itoa ptCount)
	      "���㡣(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
	    )
	  )
	  ;;(princ "\n")
	  (close f2)
	)
	;;End progn
	(princ
	  "�û�ȡ��������(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
	)
      )
      ;;end if

    )
    ;; end progn1
    (princ
      "�û�ȡ��������(C)�й��罨һ����������������� ���� 2017.05 cehui@139.com\n"
    )
  )
  ;;end if1
  (princ)
)
;;��������ε������ļ���ɾ�������ڵ��ε�------------------------------------------------------------;;


;;������̱߳��----------------------------------------------------------------------------------;;
(defun c:zzBC (/		  i		     judge
	       varBarPosition	  varOrigin	     varBarPosition_tmp
	       varTextHeight	  varBarPositionLevel
	       varLength_tmp	  varLength	     varBarStartLevel
	       varBarEndPositionLevel		     varBarEndLevel
	       varBarStartX	  varBarStartY	     varBarsCount
	       varStartY	  varEndX	     varEndY
	       varPts
	      )
  (setq i 0)
  (setq judge 0)
  (grtext -1 "���Ʊ�� ����")
  (princ "\n")
  (setq varOrigin (getpoint "������һ�㣺"))
  (princ "\n")
  (if (/= varLevel nil)
    (progn (setq varLevel_tmp varLevel)
	   (setq PromptTmp (strcat "�õ�߳�" "<" (rtos varLevel 2 3) ">:"))
    )
    (setq PromptTmp "�õ�̣߳�")
  )
  ;;(while (<= (setq varLevel (getreal PromptTmp)) 0))
  (if (= (setq varLevel (getreal PromptTmp)) nil)
    (setq varLevel varLevel_tmp)
  )
  (princ "\n")
  (if (/= varBarPosition_tmp nil)
    (setq PromptTmp (strcat "��߾���"
			    "<"
			    (rtos (car varBarPosition_tmp) 2 3)
			    ","
			    (rtos (cadr varBarPosition_tmp) 2 3)
			    ">:"
		    )
    )
    (setq PromptTmp "��߾��룺")
  )
  (princ "\n")
  (if (= (setq varBarPosition (getpoint PromptTmp)) nil)
    (setq varBarPosition varBarPosition_tmp)
  )
  (setq varBarPosition_tmp varBarPosition)
  ;;ѡ���ߵĶ���
  (if (/= varLength_tmp nil)
    (setq PromptTmp (strcat "��߳���"
			    "<"
			    (rtos (car varLength_tmp) 2 3)
			    ","
			    (rtos (cadr varLength_tmp) 2 3)
			    ">:"
		    )
    )
    (setq PromptTmp "��߳��ȣ�")
  )
  (princ "\n")
  (if (= (setq varLength (getpoint PromptTmp)) nil)
    (setq varLength varLength_tmp)
  )
  (setq varLength_tmp varLength)

  (princ "\n")
  (if (/= varScale_tmp nil)
    (setq
      PromptTmp	(strcat "�����߷�ĸ" "<" (rtos varScale_tmp 2 3) ">:")
    )
    (setq PromptTmp "�����߷�ĸ��")
  )
  (if (= (setq varScale (getint PromptTmp)) nil)
    (setq varScale varScale_tmp)
  )

  (if (and (/= nil varScale)
	   (/= nil varScale)
	   (/= nil varBarPosition)
	   (/= nil varLength)
	   (/= nil varOrigin)
      )
    ;;if main
    (progn
      ;;progn main

      ;;��ȷ����߳���ʱ�������·����и���
      (if (<= (cadr varLength) (cadr varBarPosition))
	(setq varLength
	       (list (car varLength)
		     (+	(cadr varBarPosition)
			(abs (- (cadr varLength) (cadr varBarPosition)))
		     )
	       )
	)

      )

      (setq varScale_tmp varScale)
      (setq varScale (/ varScale 100))
      ;;������ÿcm����
      (setq varTextHeight (* (/ varScale 10.0) 1.5))
      ;;���ָ߶ȼ����Ϊ1.5mm
      (EntMakeTextStyle
	"LevelBar" varTextHeight 1 "simhei.ttf"	"")
      (EntMakeLayer "2-����-���" 1)
      ;;ȷ��������߳�
      (setq varBarPositionLevel
	     (+	(- (cadr varBarPosition) (cadr varOrigin))
		varLevel
	     )
      )
      (setq varBarStartLevel (fix (+ varBarPositionLevel 0.5)))
      ;;������������������߳�
      ;;ȷ������յ�߳�
      (setq varBarEndPositionLevel
	     (+	(- (cadr varLength) (cadr varOrigin))
		varLevel
	     )
      )
      (setq varBarEndLevel (fix (+ varBarEndPositionLevel 0.5)))
      ;;������������������߳�
      ;;ȷ������������
      (setq varBarStartX (car varBarPosition))
      (setq varBarStartY
	     (+	(cadr varBarPosition)
		(- varBarStartLevel varBarPositionLevel)
	     )
      )
      (setq varBarsCount
	     (+	(atoi
		  (rtos
		    (/ (- varBarEndLevel varBarStartLevel) varScale)
		    2
		    0
		  )
		)
		1
	     )
      )

      (setq varBarsCount (* (fix (+ (/ varBarsCount 2) 0.5)) 2))

      (while (/= varBarsCount 0)
	(setq varStartY (+ varBarStartY (* i varScale)))

	(setq varEndX (- varBarStartX (* (/ varScale 10.0) 1.5)))
	(setq varEndY (+ varBarStartY (* (+ i 1) varScale)))


	(setq Fp (list varBarStartX varStartY))
	(setq Ep (list varEndX varEndY))

	(setq Lfp (list varBarStartX varStartY))
	(setq Lep (list (+ varBarStartX (/ varScale 10.0)) varStartY))

	(setq
	  Txtp
	   (list (+ varBarStartX (* (/ varScale 10.0) 2.0)) varEndY)
	)
	(setq Hi (+ varBarStartLevel (* varScale i)))
	(setq
	  Loe (list (+ (/ varScale 10.0) varBarStartX) varBarStartY)
	)
	(if (= judge 0)
	  (progn
	    (setq SolidBarFp
		   (list (/ (+ (car Fp) (car Ep)) 2) (cadr Fp))
	    )
	    ;;ʵ�ı�����
	    (setq SolidBarEp
		   (list (/ (+ (car Fp) (car Ep)) 2) (cadr Ep))
	    )
	    ;;ʵ�ı���յ�
	    (entMakePLineThick
	      (list SolidBarFp SolidBarEp)
	      varTextHeight
	      "2-����-���"
	    )
	    (EntMakeLine
	      (car lfp)
	      (cadr Lfp)
	      (car Lep)
	      (cadr Lep)
	      "2-����-���"
	    )
	    (EntMakeText
	      (+ varBarStartX (* (/ varScale 10.0) 1.1))
	      varStartY
	      (itoa Hi)
	      varTextHeight
	      "LevelBar"
	      "2-����-���"
	    )
	    (setq judge 1)
	  )
	  (progn
	    (setq varPts nil)
	    (setq varPts (cons (list varBarStartX varStartY) varPts))
	    (setq varPts (cons (list varBarStartX varEndY) varPts))
	    (setq varPts (cons (list varEndX varEndY) varPts))
	    (setq varPts (cons (list varEndX varStartY) varPts))
	    (entMakePLine varPts "2-����-���")
	    (setq judge 0)
	  )
	)
	(setq i (+ i 1))
	(setq varBarsCount (- varBarsCount 1))
      )
      (if (= judge 0)
	(progn
	  (setq Lfp (list varBarStartX varEndY))
	  (setq Lep (list (+ varBarStartX (/ varScale 10.0)) varEndY))
	  (setq Hi (+ varBarStartLevel (* varScale i)))
	  (EntMakeLine
	    (car lfp)
	    (cadr Lfp)
	    (car Lep)
	    (cadr Lep)
	    "2-����-���"
	  )
	  (EntMakeText
	    (+ varBarStartX (* (/ varScale 10.0) 1.1))
	    varEndY
	    (itoa Hi)
	    varTextHeight
	    "LevelBar"
	    "2-����-���"
	  )
	)
      )
      (princ
	"\n(C)�й��罨һ����������������� ���� cehui@139.com"
      )
      (vl-cmdf "regen")
      (princ)
    )
    ;;end progn main
    (progn
      (princ
	"\n��������밴��ʾ���룡 (C)�й��罨һ����������������� ���� cehui@139.com"
      )
      (princ)
    )
  )
  ;;end if main

)

;;������̱߳��----------------------------------------------------------------------------------;;

(defun C:zzHelp ()
  (alert
    "    �й��罨һ�����������������\n\n\n    :: zzFGW               -���ɷ��������������ļ�(D:��)\n    :: zzArea2Table     -��������AutoCAD���\n    :: zzArea2File        -���������ļ�\n    :: zzA                    -��ע�������������\n    :: zzQydx               -������Σ�ɾ��ָ�����������ĵ��ε�\n    :: zzQywdx            -��������Σ�ɾ��ָ����������ڵĵ��ε�\n    :: zzBC                  -�����̱߳�ߣ����ƺ����ͼ�ĸ̱߳��\n    :: zzExport2Dat      -CASS����ͼ�����ޱ��������ļ�(.dat)\n    ::zzHelp                -�鿴���������ʾ��Ϣ\n\n\n                       (C) ���� 20170928 QQ:61902475"  )
  (princ)
)

;;CASS����ͼ�����ޱ��������ļ�----------------------------------------------------------------------------------;;
(defun C:zzExport2Dat ()
  (vl-load-com)
  (setq	filename
	 (getfiled "����Ϊ..."
		   (getvar "dwgprefix")
		   "dat;csv"
		   1
	 )
  )
;;;ѡ�����е��ε�ͼ��
  (SETQ	SS (ssget "x"
		  (list
		    '(0 . "INSERT")
		    (cons 8 "gcd")
		  )
	   )
  )
;;;��ȡ�����꼴���ε�����
  (if (and (/= ss nil) (/= filename nil)) ;if1
    (progn				;progn1
      (setq fileId (open filename "w"))
      (setq i 0)
      (repeat (sslength ss)
	(setq ssn (ssname ss i))
	(setq endata (assoc '10 (entget ssn)))
	(if (/= endata nil)
	  (progn
	    ;;��ȡ��ɫֵ
	    (setq pcolor (cdr (assoc '62 (entget ssn))))
	    (if	(/= pcolor nil)
	      (setq pcolor_str (strcat "co" (itoa pcolor)))
	      (setq pcolor_str "")
	    )
	    (setq pxyz (cdr endata))
	    (setq px (car pxyz))
	    (setq py (cadr pxyz))
	    (setq pz (caddr pxyz))
	    (setq pxyz_str (strcat (itoa (+ i 1))
				   ","
				   pcolor_str
				   ","
				   (rtos px 2 3)
				   ","
				   (rtos py 2 3)
				   ","
				   (rtos pz 2 3)
			   )
	    )
	    (write-line pxyz_str fileId)
	  )
	)
	(setq i (1+ i))
      )
      (setq fileId (close fileId))
      (princ (strcat "������"
		     (itoa i)
		     "��CASS���ε㣡 (C)���� 201709 QQ:61902475"
	     )
      )
    )					;end progn1
    (princ
      "ͼ��û���ҵ�CASS���ε��δ�����ļ�����(C)���� 201709 QQ:61902475"
    )
  )					;end if1
  (princ)
)
;;;CASS����ͼ�е��������
;;;((-1 . <ͼԪ��: 7ffffb491b0>) (0 . "INSERT") (330 . <ͼԪ��: 7ffffb6d980>) (5 . "9A4AB") (100 . "AcDbEntity")
;;(67 . 0) (410 . "Model") (8 . "GCD") (6 . "Continuous") (100 . "AcDbBlockReference") (66 . 1) (2 . "GC200")
;;(10 269544.0 3.74404e+006 2713.01) (41 . 0.5) (42 . 0.5) (43 . 0.5) (50 . 0.0) (70 . 0) (71 . 0) (44 . 0.0)
;;(45 . 0.0) (210 0.0 0.0 1.0))
;;CASS����ͼ�����ޱ��������ļ�----------------------------------------------------------------------------------;;


;;�Զ���ͨ�ú���----------------------------------------------------------------------------------;;

;;�÷���(EntMakeText ��X ��Y �ı����� �ı��߶�)
(defun EntMakeText (px py str tHeight styleName layerName / pt)
  (setq pt (list px py))
  (entmakeX
    (list '(0 . "TEXT")
	  (cons 1 str)
	  (cons 10 pt)
	  (cons 7 styleName)
	  (cons 8 layerName)
	  (cons 40 tHeight)
    )
  )
)

;;�÷���(EntMakeLine ���X ���Y �յ�X �յ�Y)
(defun EntMakeLine (xa ya xb yb layerName / p1 p2)
  (setq	p1 (list xa ya)
	p2 (list xb yb)
  )
  (entmakeX (list '(0 . "LINE")
		  '(370 . 0)
		  (cons 10 p1)
		  (cons 11 p2)
		  (cons 8 layerName)
	    )
  )
)

(defun entMakePLineThick (pts weight layerName)
  (entmake (append
	     (list '(0 . "LWPOLYLINE")
		   '(100 . "AcDbEntity")
		   '(100 . "AcDbPolyline")
		   (cons 8 layerName)
		   ;;��
		   ;;'(62 . 7)
		   ;;��ɫ��7-��ɫ
		   '
		    (370 . 0)
		   ;;�߿�0��0.20ֵΪ(370 . 20)
		   (cons 90 (length pts))
		   (cons 43 weight)
		   ;;ȫ�ֿ�
		   '
		    (70 . 0)
	     )				;list
	     (mapcar '(lambda (x)
			(cons 40 weight)
			;;����
			(cons 41 weight)
			;;�յ��
			(cons 42 0.0)
			(cons 10 x)
		      )
		     pts
	     )
	   )				;append
  )
)


(defun entMakePLine (pts layerName)
  (entmake (append
	     (list '(0 . "LWPOLYLINE")
		   '(100 . "AcDbEntity")
		   '(100 . "AcDbPolyline")
		   '(370 . 0)
		   (cons 8 layerName)
		   (cons 90 (length pts))
		   '(70 . 0)
	     )				;list
	     (mapcar '(lambda (x) (cons 10 x)) pts)
	   )				;append
  )
)

(defun EntMakeTextStyle	(tStyleName	  tStyleHeight
			 tStyleWeight	  tFontName
			 tBigFontName
			)
  (if (not (tblsearch "style" tStyleName))
    (entmakeX
      (list
	'(0 . "STYLE")
	'(100 . "AcDbSymbolTableRecord")
	'(100 . "AcDbTextStyleTableRecord")
	(cons 2 tStyleName)
	'(70 . 0)
	(cons 40 tStyleHeight)
	(cons 41 tStyleWeight)
	(cons 3 tFontName)
	(cons 4 tBigFontName)
      )
    )
  )
)

(defun EntMakeLayer (layname color / nlay)
  (vl-load-com)
  (or (tblsearch "layer" layname)
      (or (not (setq nlay
		      (vla-add (vla-get-layers
				 (vla-get-activedocument (vlax-get-acad-object))
			       )
			       layname
		      )
	       )
	  )
	  (vla-put-color nlay color)	;vla-put-����ֵΪnil
					;(vla-put-plottable nlay :vlax-false) ;��Ϊ����ӡ��
					;(vla-put-activelayer
					;  (vla-get-activedocument (vlax-get-acad-object))
					;  nlay
					;)
	  ;;��Ϊ��ǰ��
      )
  )
)


;;;���ܣ��ַ�����ָ���ָ����ָ�,�ָ����������ִ�������ȡ�ļ���������չ����Ϊ�ָ���
;;;(splitX "C:\\Users\\....25��K1+013.52��EL.2776.73��EL.2804.74��.dat" ".dat")
;;;���أ�(C:\\Users\\....25��K1+013.52��EL.2776.73��EL.2804.74��)
(defun splitX (str delim / LST POS)
  (while (setq pos (vl-string-search delim str))
    (setq lst (append lst (list (substr str 1 pos))))
    (setq str (substr str (+ (+ pos (strlen delim)) 1)))
  )
  (if (> (strlen str) 0)
    (append lst (list str))
    lst
  )
)


(defun pt_inorout (regionObj pt / pt_list e1 pt n i j va va_count)
  (setq	pt_list	(mapcar	'cdr
			(vl-remove-if
			  '(lambda (x) (/= 10 (car x)))
			  (entget (car regionObj))
			)
		)
  )

  (setq	i	 0
	va_count 0
	n	 (length pt_list)
	pt_list	 (append pt_list (list (car pt_list)))
  )
  (repeat n
    (setq va (-	(angle pt (nth i pt_list))
		(angle pt (nth (1+ i) pt_list))
	     )
    )
    (cond ((> va pi) (setq va (- va pi)))
	  ((< va (* -1 pi)) (setq va (+ va pi)))
    )
    (setq va_count (+ va_count va)
	  i	   (1+ i)
    )
  )
  (if (< (abs (- (abs va_count) pi)) 0.000001)
    't
    'nil
  )
)


(defun date ()
  (setq datetime (rtos (getvar "cdate") 2 6))
  (car (splitx datetime "."))
)

(defun time ()
  (setq datetime (rtos (getvar "cdate") 2 6))
  (cadr (splitx datetime "."))
)
;;ɾ����������ε�------------------------------------------------------------;;


(vl-load-com)
(princ)
(princ
  "\n:: һ��������������� | Ver:20170520 | ���� �й��罨һ�����������������::"
)
(princ "\n:: zzFGW       -���ɷ��������������ļ�(D:��)")
(princ "\n:: zzArea2Table-��������AutoCAD���")
(princ "\n:: zzArea2File -���������ļ�")
(princ "\n:: zzA         -��ע�������������")
(princ
  "\n:: zzQydx      -������Σ�ɾ��ָ�����������ĵ��ε�"
)
(princ
  "\n:: zzQywdx     -��������Σ�ɾ��ָ����������ڵĵ��ε�"
)
(princ
  "\n:: zzBC        -�����̱߳�ߣ����ƺ����ͼ�ĸ̱߳��"
)
(princ
  "\n:: zzExport2Dat        -CASS����ͼ�����ޱ��������ļ�(.dat)"
)
(princ "\n:: zzHelp         -�鿴���������ʾ��Ϣ")
(princ)

;;------------------------------------------------------------;;
;;                         End of File                        ;;
;;------------------------------------------------------------;;

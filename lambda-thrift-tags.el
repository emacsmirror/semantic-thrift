;;; lambda-thrift-tags.el --- Thrift LALR parser for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2022 Guanghui Xu
;;
;; Author: Guanghui Xu gh_xu@qq.com
;; Maintainer: Guanghui Xu gh_xu@qq.com
;; Created: 2022-11-29
;; Version: 0.0.1
;; Keywords:
;; Homepage: not distributed yet
;; Package-Version: 0.0.1
;; Package-Requires:
;;

;; This file is not part of GNU Emacs.

;;; Commentary:

;;

;; Put this file into your load-path and the following into your ~/.emacs:
;;   (require 'lambda-thrift-tags)

;;; Change Log:

;; Version $(3) 2022-11-29 GuanghuiXu
;;   - Initial release

;;; Code:

;; (add-to-list 'load-path "/Users/bytedance/repository/public/lambda-thrift")
;; (require 'thrift-wy)
;; (require 'lambda-thrift-tags)
;; (add-to-list 'semantic-new-buffer-setup-functions '(thrift-mode . lambda-thrift-default-setup))

(require 'semantic/wisent)
(require 'semantic/ctxt)
(require 'semantic/tag-file)
(require 'semantic/analyze)
(require 'semantic/java)
(require 'semantic/db-typecache)
(require 'cc-mode)
(require 'lambda-thrift-wy)
(require 'thrift)

;;;;
;;;; Simple parser error reporting function
;;;;

(defun lambda-thrift-parse-error (msg)
  "Error reporting function called when a parse error occurs.
MSG is the message string to report."
  (message msg)
  ;;(debug)
  )

(define-mode-local-override semantic-dependency-tag-file thrift-mode (tag)
  "Find the filename represented from TAG."
  (unless (semantic-tag-of-class-p tag 'include)
    (signal 'wrong-type-argument (list tag 'include)))

  (let ((tfile (semantic-tag-include-filename tag)))
    (if (and (string-prefix-p "\"" tfile) (string-suffix-p "\"" tfile))
        (expand-file-name (substring tfile 1 -1))
        (expand-file-name tfile))))

(define-mode-local-override semantic-analyze-find-tag-sequence thrift-mode (sequence &optional scope typereturn throwsym &rest flags)
  "Attempt to find all tags in SEQUENCE.
Optional argument LOCALVAR is the list of local variables to use when
finding the details on the first element of SEQUENCE in case
it is not found in the global set of tables.
Optional argument SCOPE are additional terminals to search which are currently
scoped.  These are not local variables, but symbols available in a structure
which doesn't need to be dereferenced.
Optional argument TYPERETURN is a symbol in which the types of all found
will be stored.  If nil, that data is thrown away.
Optional argument THROWSYM specifies a symbol the throw on non-recoverable
error.
Remaining arguments FLAGS are additional flags to apply when searching."
  ;; (message "semantic-analyze-find-tag-sequence,sequence:%S" sequence)
  (let ((result (semantic-analyze-find-tag-sequence-default sequence scope typereturn throwsym flags)))
    (let ((filtered-result (seq-filter (lambda (ele)
                                         (if (equal 'include (semantic-tag-class ele))
                                             (equal (car (last sequence)) (semantic-tag-get-attribute ele :alias))
                                           t))
                                       result)))
      (if (length> filtered-result 0)
          filtered-result
        (semantic-analyze-find-tag-sequence-default (last sequence) scope typereturn throwsym flags)))))

(define-mode-local-override semanticdb-typecache-find thrift-mode (type &optional path find-file-match)
  "Search the typecache for TYPE in PATH.
If type is a string, split the string, and search for the parts.
If type is a list, treat the type as a pre-split string.
PATH can be nil for the current buffer, or a semanticdb table.
FIND-FILE-MATCH is non-nil to force all found tags to be loaded into a buffer."
  ;; (message "semanticdb-typecache-find,type:%S,stringp:%S" type (stringp type))
  (let ((result (semanticdb-typecache-find-default type path find-file-match)))
    (if result result
      (dolist (ele (semantic-find-tags-by-class 'include semanticdb-current-table) result)
        (if (or (and (listp type) (equal (car type)(semantic-tag-get-attribute ele :alias)))
                (and (stringp type) (equal type (semantic-tag-get-attribute ele :alias))))
            (setq result ele)))
      )
    result))

(setq-mode-local thrift-mode
                 semanticdb-find-default-throttle
                 '(local recursive project unloaded system))

;;;###autoload
(defvar lambda-thrift-syntax-table
  (let ((table (copy-syntax-table java-mode-syntax-table)))
    ;; Comments can start with //, /* or # characters.
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?# "< b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\^m "> b" table)

    table)
  "Syntax table used in `thrift-mode' buffers.")


;;;;
;;;; Semantic integration of the Thrift LALR parser
;;;;

;; In semantic/imenu.el, not part of Emacs.
(defvar semantic-imenu-summary-function)

;;;###autoload
(defun lambda-thrift-default-setup ()
  "Hook run to setup Semantic in `thrift-mode'.
Use the alternate LALR(1) parser."
  (lambda-thrift-wy--install-parser)
  (setq
   ;; Lexical analysis
   semantic-lex-number-expression semantic-java-number-regexp
   semantic-lex-analyzer #'lambda-thrift-lexer
   semantic-lex-syntax-table lambda-thrift-syntax-table
   semantic-lex-comment-regex "\\(\\s<\\|\\(?://+\\|/\\*+\\)\\s *\\)"
   ))

(add-to-list 'semantic-new-buffer-setup-functions '(thrift-mode . lambda-thrift-default-setup))

(provide 'lambda-thrift-tags)

;;; lambda-thrift-tags.el ends here

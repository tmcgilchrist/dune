;;; dune.el --- Integration with the dune build system  -*- lexical-binding: t; -*-

;; Copyright 2018 Jane Street Group, LLC <opensource@janestreet.com>
;;           2017- Christophe Troestler
;; URL: https://github.com/ocaml/dune
;; Version: 1.0
;; Package-Requires: ((emacs "26.3"))

;;; Commentary:

;; This package provides helper functions for interacting with the
;; dune build system from Emacs.  It also prevides a mode to edit dune
;; files.

;; Installation:
;; You need to install the OCaml program ``dune''.  The
;; easiest way to do so is to install the opam package manager:
;;
;;   https://opam.ocaml.org/doc/Install.html
;;
;; and then run "opam install dune".

;; This file is not part of GNU Emacs.

;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
;; WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS.  IN NO EVENT SHALL THE
;; AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
;; CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
;; LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
;; NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
;; CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

;;; Code:

(defgroup dune nil
  "Integration with the dune build system."
  :tag "Dune build system."
  :version "1.0"
  :group 'languages)

(defcustom dune-use-tree-sitter nil
  "Use tree-sitter for syntax highlighting and indentation.
When non-nil, use tree-sitter-dune for parsing, syntax highlighting,
and indentation instead of the traditional font-lock and SMIE-based
approach. Requires Emacs 29+ with tree-sitter support."
  :type 'boolean
  :group 'dune)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                    Tree-sitter support

;; Load treesit if available (Emacs 29+)
(require 'treesit nil t)

(defun dune--tree-sitter-available-p ()
  "Check if tree-sitter is available in this Emacs."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)))

;; Tree-sitter grammar installation
;;
;; BRANCHING STRATEGY AND ABI COMPATIBILITY:
;;
;; Tree-sitter ABI support depends on which tree-sitter library version
;; Emacs was built against, NOT the Emacs version number:
;;
;; - tree-sitter 0.20.x - 0.24.x: supports ABI 13-14
;; - tree-sitter 0.25.x: supports ABI 13-15
;;
;; Both Emacs 29.x and 30.x can support different ABI ranges depending on
;; their build configuration. For maximum compatibility, we use ABI 14:
;;
;; - Works with all tested Emacs 29.x builds
;; - Works with all tested Emacs 30.x builds (even those built with 0.25.x)
;; - More portable than ABI 15 (which requires 0.25.x)
;;
;; BRANCH USAGE:
;; - `emacs-29` branch: Grammars regenerated with --abi=14 for compatibility
;; - `master` branch: May use ABI 15 (future, when universally supported)

;; TODO: Update this URL to point to official repository once available
;; Currently using tmcgilchrist's repo with emacs-29 branch for ABI 14
(defvar dune-treesitter-grammar
  '(dune "https://github.com/tmcgilchrist/tree-sitter-dune" "emacs-29" "src")
  "Tree-sitter grammar specification for dune.
Format: (LANGUAGE REPO-URL REVISION SOURCE-DIR)
See above commentary for details on ABI compatibility strategy.")

(defun dune-treesitter--install-grammar-noninteractive ()
  "Install tree-sitter-dune grammar without prompting.
Used internally by dune-mode that has already prompted the user."
  (unless (version<= "29.1" emacs-version)
    (user-error "Tree-sitter requires Emacs 29.1 or later"))

  ;; Add our grammar to the source list
  (unless (assq 'dune treesit-language-source-alist)
    (push dune-treesitter-grammar treesit-language-source-alist))

  ;; Install if missing
  (unless (treesit-language-available-p 'dune)
    (message "Installing tree-sitter-dune...")
    (treesit-install-language-grammar 'dune)))

;;;###autoload
(defun dune-treesitter-install-grammar ()
  "Install tree-sitter grammar for dune.
Checks if the grammar is available and offers to install if missing."
  (interactive)
  (unless (version<= "29.1" emacs-version)
    (user-error "Tree-sitter requires Emacs 29.1 or later"))

  ;; Add our grammar to the source list
  (unless (assq 'dune treesit-language-source-alist)
    (push dune-treesitter-grammar treesit-language-source-alist))

  ;; Check if installed
  (if (treesit-language-available-p 'dune)
      (message "Tree-sitter-dune grammar is already installed!")
    (when (yes-or-no-p "Tree-sitter grammar for dune not found. Install it? ")
      (message "Installing tree-sitter-dune...")
      (condition-case err
          (progn
            (treesit-install-language-grammar 'dune)
            (message "Tree-sitter-dune grammar installed successfully!"))
        (error
         (message "Failed to install tree-sitter-dune: %s" err))))))

(defun dune--ensure-tree-sitter-grammar ()
  "Ensure tree-sitter-dune grammar is installed.
If not installed, prompt user and install it from the GitHub repository."
  (when (dune--tree-sitter-available-p)
    (unless (treesit-ready-p 'dune)
      (if (yes-or-no-p "Tree-sitter grammar for dune not found. Install it now? ")
          (progn
            (dune-treesitter--install-grammar-noninteractive)
            ;; Re-check after installation
            (unless (treesit-ready-p 'dune)
              (error "Failed to install tree-sitter grammar for dune")))
        (error "Tree-sitter for dune isn't available. Run M-x dune-treesitter-install-grammar")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;               Syntax highlighting of dune files

(defface dune-error-face
  '((t (:inherit error)))
  "Face for errors (e.g. obsolete constructs)."
  :group 'dune)

(defvar dune-error-face 'dune-error-face
  "Face for errors (e.g. obsolete constructs).")

(defface dune-separator-face
  '((t (:inherit default)))
  "Face for various kind of separators such as ':'."
  :group 'dune)
(defvar dune-separator-face 'dune-separator-face
  "Face for various kind of separators such as ':'.")

(defconst dune-stanzas-regex
  (eval-when-compile
    (concat (regexp-opt
             '("library" "executable" "executables" "rule" "toplevel"
               "ocamllex" "ocamlyacc" "menhir" "alias" "install"
               "copy_files" "copy_files#" "include" "tests" "test" "dirs"
               "env" "ignored_subdirs" "include_subdirs" "data_only_dirs"
               "documentation" "cinaps" "coqlib" "coq.theory" "coq.pp"
               "foreign_library")
             ) "\\(?:\\_>\\|[[:space:]]\\)"))
  "Stanzas in dune files.")

(defconst dune-fields-regex
  (eval-when-compile
    (regexp-opt
     '("name" "public_name" "synopsis" "modules" "libraries" "wrapped"
       "preprocess" "preprocessor_deps" "optional" "c_names" "cxx_names"
       "foreign_stubs" "foreign_archives" "install_c_headers" "modes"
       "no_dynlink" "kind" "ppx_runtime_libraries" "virtual_deps" "js_of_ocaml"
       "flags" "ocamlc_flags" "ocamlopt_flags" "library_flags" "c_flags"
       "cxx_flags" "c_library_flags" "self_build_stubs_archive" "inline_tests"
       "modules_without_implementation" "private_modules"
       ;; + special_builtin_support
       "special_builtin_support" "build_info" "data_module" "api_version"
       ;; +stdlib
       "stdlib" "modules_before_stdlib" "exit_module" "internal_modules"
       ;; + virtual libraries
       "virtual_modules" "implements" "variant" "default_implementation"
       "allow_overlapping_dependencies"
       ;; + for "executable" and "executables":
       "package" "link_flags" "link_deps" "names" "public_names" "variants"
       "forbidden_libraries"
       ;; + for "foreign_library" and "foreign_stubs":
       "archive_name" "language" "names" "flags" "include_dirs" "extra_deps"
       ;; + for "rule":
       "targets" "action" "deps" "mode" "fallback" "locks"
       ;; + for "menhir":
       "merge_into"
       ;; + for "cinaps":
       "files"
       ;; + for "alias"
       "enabled_if"
       ;; + for env
       "binaries"
       ;; + for "install"
       "section" "files"
       ;; Coq fields
       "theories" "modules_flags" "plugins")
     'symbols))
  "Field names allowed in dune files.")

(defconst dune-builtin-regex
  (eval-when-compile
    (concat (regexp-opt
             '(;; Linking modes
               "byte" "native" "best"
               ;; modes
               "standard" "fallback" "promote" "promote-until-clean"
               ;; Actions
               "run" "chdir" "setenv"
               "with-stdout-to" "with-stderr-to" "with-outputs-to"
               "ignore-stdout" "ignore-stderr" "ignore-outputs"
               "with-stdin-from" "with-exit-codes"
               "progn" "echo" "write-file" "cat" "copy" "copy#" "system"
               "bash" "diff" "diff?" "cmp"
               ;; FIXME: "flags" is already a field and we do not have enough
               ;; context to distinguishing both.
               "backend" "generate_runner" "runner_libraries" "flags"
               "extends"
               ;; Dependency specification
               "file" "alias" "alias_rec" "glob_files" "files_recursively_in"
               "universe" "package" "source_tree" "env_var")
             t)
            "\\(?:\\_>\\|[[:space:]]\\)"))
  "Builtin sub-fields in dune.")

(defconst dune-builtin-labels-regex
  (regexp-opt '("standard" "include") 'words)
  "Builtin :labels in dune.")

(defvar dune-var-kind-regex
  (eval-when-compile
    (regexp-opt
     '("ocaml-config"
       "dep" "exe" "bin" "lib" "libexec" "lib-available"
       "version" "read" "read-lines" "read-strings")
     'words))
  "Optional prefix to variable names.")

(defmacro dune--field-vals (field &rest vals)
  "Build a `font-lock-keywords' rule for the dune FIELD accepting values VALS."
  `(list (concat "(" ,field "[[:space:]]+" ,(regexp-opt vals t))
         1 font-lock-constant-face))

(defvar dune-font-lock-keywords
  `((,(concat "(\\(" dune-stanzas-regex "\\)") 1 font-lock-keyword-face)
    ("([^ ]+ +\\(as\\) +[^ ]+)" 1 font-lock-keyword-face)
    (,(concat "(" dune-fields-regex) 1 font-lock-function-name-face)
    (,(concat "%{" dune-var-kind-regex " *\\(\\:\\)[^{}:]*\\(\\(?::\\)?\\)")
     (1 font-lock-builtin-face)
     (2 dune-separator-face)
     (3 dune-separator-face))
    ("%{\\([^{}]*\\)}" 1 font-lock-variable-name-face keep)
    (,(concat "\\(:" dune-builtin-labels-regex "\\)[[:space:]()\n]")
     1 font-lock-builtin-face)
    ;; Named dependencies:
    ("(\\(:[a-zA-Z]+\\)[[:space:]]+" 1 font-lock-variable-name-face)
    ("\\(true\\|false\\)" 1 font-lock-constant-face)
    ("(\\(select\\)[[:space:]]+[^[:space:]]+[[:space:]]+\\(from\\)\\>"
     (1 font-lock-constant-face)
     (2 font-lock-constant-face))
    ,(eval-when-compile
       (dune--field-vals "kind" "normal" "ppx_rewriter" "ppx_deriver"))
    ,(eval-when-compile
       (dune--field-vals "mode" "standard" "fallback" "promote"
                                "promote-until-clean"))
    (,(concat "(" dune-builtin-regex) 1 font-lock-builtin-face)
    ("(preprocess[[:space:]]+(\\(pps\\)" 1 font-lock-builtin-face)
    ("(name +\\(runtest\\))" 1 font-lock-builtin-face)
    (,(eval-when-compile
        (concat "(" (regexp-opt '("fallback") t)))
     1 dune-error-face)))

(defvar dune-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?\; "< b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    table)
  "Dune syntax table.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                Tree-sitter font-lock

(defvar dune--treesit-font-lock-rules
  '(:language dune
    :feature comment
    ((comment) @font-lock-comment-face)

    :language dune
    :feature string
    ([(quoted_string) (multiline_string)] @font-lock-string-face)

    :language dune
    :feature keyword
    ((stanza_name) @font-lock-keyword-face
     (blang_op) @font-lock-keyword-face)

    :language dune
    :feature builtin
    ((action_name) @font-lock-builtin-face)

    :language dune
    :feature property
    ((field_name) @font-lock-function-name-face)

    :language dune
    :feature type
    ([(module_name) (library_name) (public_name) (package_name)] @font-lock-type-face)

    :language dune
    :feature variable
    ((named_variable) @font-lock-variable-name-face)

    :language dune
    :feature constant
    ([(boolean)] @font-lock-constant-face)

    :language dune
    :feature delimiter
    (["(" ")" "[" "]"] @font-lock-bracket-face))
  "Tree-sitter font-lock settings for dune-mode.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                Tree-sitter imenu

(defun dune--treesit-defun-name (node)
  "Return the name of the defun NODE.
For dune files, this returns the stanza type and its name field if present."
  (when-let* ((stanza-node (treesit-parent-until
                            node
                            (lambda (n) (string= "stanza" (treesit-node-type n)))))
              (stanza-name-node (treesit-search-subtree stanza-node "stanza_name" t)))
    (let ((stanza-type (treesit-node-text stanza-name-node t)))
      ;; Try to find the 'name' field to create a more descriptive entry
      (if-let* ((fields (treesit-filter-child
                         stanza-node
                         (lambda (n) (string= "field_name" (treesit-node-type n)))))
                (name-field (seq-find
                             (lambda (field)
                               (string= "name" (treesit-node-text field t)))
                             fields))
                ;; Get the value after the field_name
                (name-value-node (treesit-node-next-sibling name-field))
                (name-value (when name-value-node
                              (treesit-node-text name-value-node t))))
          (format "%s:%s" stanza-type name-value)
        ;; No name field, just return the stanza type
        stanza-type))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                Tree-sitter semantic selection

(defun dune-treesitter-mark-stanza ()
  "Mark the current stanza."
  (interactive)
  (when-let* ((node (treesit-node-at (point)))
              (stanza (treesit-parent-until
                       node
                       (lambda (n) (string= "stanza" (treesit-node-type n))))))
    (goto-char (treesit-node-start stanza))
    (set-mark (treesit-node-end stanza))
    (activate-mark)
    (message "Marked stanza: %s" (treesit-node-text (treesit-search-subtree stanza "stanza_name" t) t))))

(defun dune-treesitter-mark-field ()
  "Mark the current field (field name and its value)."
  (interactive)
  (when-let* ((node (treesit-node-at (point)))
              (field-name (treesit-parent-until
                           node
                           (lambda (n) (string= "field_name" (treesit-node-type n))))))
    ;; Find the start of the field (opening paren before field_name)
    (let ((field-start (treesit-node-start field-name))
          (field-end (treesit-node-end field-name)))
      ;; Look for siblings after field_name (the values)
      (let ((sibling (treesit-node-next-sibling field-name)))
        (while sibling
          (setq field-end (treesit-node-end sibling))
          (setq sibling (treesit-node-next-sibling sibling))))
      ;; Mark from opening paren to closing paren
      (let ((parent (treesit-node-parent field-name)))
        (when parent
          (goto-char (treesit-node-start parent))
          (set-mark (treesit-node-end parent))
          (activate-mark)
          (message "Marked field: %s" (treesit-node-text field-name t)))))))

(defun dune-treesitter-mark-sexp ()
  "Mark the current s-expression."
  (interactive)
  (when-let* ((node (treesit-node-at (point)))
              (sexp (treesit-parent-until
                     node
                     (lambda (n) (or (string= "sexp" (treesit-node-type n))
                                     (string= "_list" (treesit-node-type n))
                                     (string= "action" (treesit-node-type n)))))))
    (goto-char (treesit-node-start sexp))
    (set-mark (treesit-node-end sexp))
    (activate-mark)
    (message "Marked %s" (treesit-node-type sexp))))

(defun dune-treesitter-expand-region ()
  "Expand the region to the next semantic unit.
First expands to field, then to stanza, then to entire file."
  (interactive)
  (if (not (use-region-p))
      ;; No region active, start by marking current node
      (let ((node (treesit-node-at (point))))
        (when node
          (goto-char (treesit-node-start node))
          (set-mark (treesit-node-end node))
          (activate-mark)))
    ;; Region active, expand it
    (let* ((start (region-beginning))
           (end (region-end))
           (node (treesit-node-on start end))
           (parent (when node (treesit-node-parent node))))
      (when parent
        (goto-char (treesit-node-start parent))
        (set-mark (treesit-node-end parent))
        (activate-mark)
        (let ((type (treesit-node-type parent)))
          (message "Expanded to %s" type))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                Tree-sitter error detection

(defun dune--treesit-find-errors (node)
  "Find ERROR nodes in the parse tree rooted at NODE.
Returns a list of (START END MESSAGE) tuples."
  (let ((errors '()))
    (when (string= "ERROR" (treesit-node-type node))
      (push (list (treesit-node-start node)
                  (treesit-node-end node)
                  "Syntax error: invalid or incomplete syntax")
            errors))
    ;; Recursively check children
    (let ((child (treesit-node-child node 0))
          (index 0))
      (while child
        (setq errors (append errors (dune--treesit-find-errors child)))
        (setq index (1+ index))
        (setq child (treesit-node-child node index))))
    errors))

(defun dune--treesit-validate-stanza (stanza-node)
  "Validate STANZA-NODE and return list of errors.
Returns list of (START END MESSAGE SEVERITY) tuples."
  (let ((errors '())
        (stanza-name-node (treesit-search-subtree stanza-node "stanza_name" t)))
    (when stanza-name-node
      (let ((stanza-type (treesit-node-text stanza-name-node t))
            (fields (treesit-filter-child
                     stanza-node
                     (lambda (n) (string= "field_name" (treesit-node-type n))))))

        (cond
         ;; library stanza must have 'name' field
         ((string= stanza-type "library")
          (unless (seq-find (lambda (f) (string= "name" (treesit-node-text f t))) fields)
            (push (list (treesit-node-start stanza-node)
                        (treesit-node-end stanza-name-node)
                        "library stanza requires a 'name' field"
                        :error)
                  errors)))

         ;; executable stanza must have 'name' field
         ((string= stanza-type "executable")
          (unless (seq-find (lambda (f) (string= "name" (treesit-node-text f t))) fields)
            (push (list (treesit-node-start stanza-node)
                        (treesit-node-end stanza-name-node)
                        "executable stanza requires a 'name' field"
                        :error)
                  errors)))

         ;; rule stanza should have targets and action
         ((string= stanza-type "rule")
          (unless (seq-find (lambda (f) (string= "targets" (treesit-node-text f t))) fields)
            (push (list (treesit-node-start stanza-node)
                        (treesit-node-end stanza-name-node)
                        "rule stanza should have 'targets' field"
                        :warning)
                  errors))
          (unless (seq-find (lambda (f) (string= "action" (treesit-node-text f t))) fields)
            (push (list (treesit-node-start stanza-node)
                        (treesit-node-end stanza-name-node)
                        "rule stanza should have 'action' field"
                        :warning)
                  errors))))

        ;; Check for duplicate field names
        (let ((field-names (mapcar (lambda (f) (treesit-node-text f t)) fields))
              (seen '()))
          (dolist (field-name field-names)
            (when (member field-name seen)
              (let ((dup-node (seq-find (lambda (f) (string= field-name (treesit-node-text f t))) fields)))
                (push (list (treesit-node-start dup-node)
                            (treesit-node-end dup-node)
                            (format "Duplicate field '%s'" field-name)
                            :warning)
                      errors)))
            (push field-name seen)))))
    errors))

(defun dune--treesit-collect-diagnostics ()
  "Collect all tree-sitter diagnostics for the current buffer.
Returns list of (START END MESSAGE SEVERITY) tuples."
  (when-let ((parser (car (treesit-parser-list)))
             (root (treesit-parser-root-node parser)))
    (let ((diagnostics '()))

      ;; Find parse errors (ERROR nodes)
      (let ((parse-errors (dune--treesit-find-errors root)))
        (dolist (err parse-errors)
          (push (list (nth 0 err) (nth 1 err) (nth 2 err) :error) diagnostics)))

      ;; Validate each stanza
      (let ((stanzas (treesit-filter-child
                      root
                      (lambda (n) (string= "stanza" (treesit-node-type n))))))
        (dolist (stanza stanzas)
          (setq diagnostics (append diagnostics (dune--treesit-validate-stanza stanza)))))

      diagnostics)))

(defun dune-treesitter-flymake-backend (report-fn &rest _args)
  "Flymake backend using tree-sitter for syntax checking.
REPORT-FN is the callback to report diagnostics."
  (if (not (and (dune--tree-sitter-available-p)
                dune-use-tree-sitter
                (treesit-parser-list)))
      ;; No tree-sitter available or not enabled
      (funcall report-fn nil)
    ;; Collect diagnostics
    (let* ((source-buffer (current-buffer))
           (diagnostics-data (dune--treesit-collect-diagnostics))
           (flymake-diagnostics '()))

      (dolist (diag diagnostics-data)
        (let ((start (nth 0 diag))
              (end (nth 1 diag))
              (message (nth 2 diag))
              (severity (nth 3 diag)))
          (push (flymake-make-diagnostic
                 source-buffer
                 start
                 end
                 severity
                 message)
                flymake-diagnostics)))

      (funcall report-fn (nreverse flymake-diagnostics)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                Tree-sitter indentation

(defvar dune--treesit-indent-rules
  `((dune
     ;; Top-level: stanzas at column 0
     ((parent-is "source_file") column-0 0)

     ;; Closing delimiters align with opening
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)

     ;; Stanza contents indented by 1
     ((parent-is "stanza") parent-bol 1)

     ;; Field contents indented by 1 from field
     ((parent-is "field") parent-bol 1)

     ;; Actions indented by 1
     ((parent-is "action") parent-bol 1)

     ;; S-expressions (generic lists) indented by 1
     ((parent-is "sexp") parent-bol 1)
     ((parent-is "_list") parent-bol 1)

     ;; Boolean expressions
     ((parent-is "blang") parent-bol 1)

     ;; Default: indent by 1
     (no-node parent-bol 1)))
  "Tree-sitter indentation rules for dune-mode.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                             SMIE

(require 'smie)

(defvar dune-smie-grammar
  (smie-prec2->grammar
   (smie-bnf->prec2 '())))

(defun dune-smie-rules (kind token)
  "Rules for `smie-setup'.
See `smie-rules-function' for the meaning of KIND and TOKEN."
  (cond
   ((eq kind :close-all) '(column . 0))
   ((and (eq kind :after) (equal token ")"))
    (save-excursion
      (goto-char (cadr (smie-indent--parent)))
      (if (looking-at-p dune-stanzas-regex)
          '(column . 0)
        1)))
   ((eq kind :before)
    (if (smie-rule-parent-p "(")
        (save-excursion
          (goto-char (cadr (smie-indent--parent)))
          (cond
           ((looking-at-p dune-stanzas-regex) 1)
           ((looking-at-p dune-fields-regex)
            (smie-rule-parent 0))
           ((smie-rule-sibling-p) (cons 'column (current-column)))
           (t (cons 'column (current-column)))))
      '(column . 0)))
   ((eq kind :list-intro)
    nil)
   (t 1)))

(defun dune-smie-rules-verbose (kind token)
  "Same as `dune-smie-rules' but echoing information.
See `smie-rules-function' for the meaning of KIND and TOKEN."
  (let ((value (dune-smie-rules kind token)))
    (message
     "%s '%s'; sibling-p:%s parent:%s hanging:%s = %s"
     kind token
     (ignore-errors (smie-rule-sibling-p))
     (ignore-errors smie--parent)
     (ignore-errors (smie-rule-hanging-p))
     value)
    value))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                          Skeletons
;; See Info node "Autotype".

(define-skeleton dune-insert-library-form
  "Insert a library stanza."
  nil
  "(library" > \n
  "(name        " _ ")" > \n
  "(public_name " _ ")" > \n
  "(libraries   " _ ")" > \n
  "(synopsis \"" _ "\"))" > ?\n)

(define-skeleton dune-insert-executable-form
  "Insert an executable stanza."
  nil
  "(executable" > \n
  "(name        " _ ")" > \n
  "(public_name " _ ")" > \n
  "(modules     " _ ")" > \n
  "(libraries   " _ "))" > ?\n)

(define-skeleton dune-insert-executables-form
  "Insert an executables stanza."
  nil
  "(executables" > \n
  "(names        " _ ")" > \n
  "(public_names " _ ")" > \n
  "(libraries    " _ "))" > ?\n)

(define-skeleton dune-insert-rule-form
  "Insert a rule stanza."
  nil
  "(rule" > \n
  "(targets " _ ")" > \n
  "(deps    " _ ")" > \n
  "(action  (" _ ")))" > ?\n)

(define-skeleton dune-insert-ocamllex-form
  "Insert an ocamllex stanza."
  nil
  "(ocamllex (" _ "))" > ?\n)

(define-skeleton dune-insert-ocamlyacc-form
  "Insert an ocamlyacc stanza."
  nil
  "(ocamlyacc (" _ "))" > ?\n)

(define-skeleton dune-insert-menhir-form
  "Insert a menhir stanza."
  nil
  "(menhir" > \n
  "((modules (" _ "))))" > ?\n)

(define-skeleton dune-insert-alias-form
  "Insert an alias stanza."
  nil
  "(alias" > \n
  "(name " _ ")" > \n
  "(deps " _ "))" > ?\n)

(define-skeleton dune-insert-install-form
  "Insert an install stanza."
  nil
  "(install" > \n
  "(section " _ ")" > \n
  "(files   " _ "))" > ?\n)

(define-skeleton dune-insert-copyfiles-form
  "Insert a copy_files stanza."
  nil
  "(copy_files " _ ")" > ?\n)

(define-skeleton dune-insert-test-form
  "Insert a test stanza."
  nil
  "(test" > \n
  "(name " _ "))" > ?\n)

(define-skeleton dune-insert-tests-form
  "Insert a tests stanza."
  nil
  "(tests" > \n
  "(names " _ "))" > ?\n)

(define-skeleton dune-insert-env-form
  "Insert a env stanza."
  nil
  "(env" > \n
  "(" _ " " _ "))" > ?\n)

(define-skeleton dune-insert-ignored-subdirs-form
  "Insert a ignored_subdirs stanza."
  nil
  "(ignored_subdirs (" _ "))" > ?\n)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar dune-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\C-c\C-c" 'compile)
    (define-key map "\C-c.l" 'dune-insert-library-form)
    (define-key map "\C-c.e" 'dune-insert-executable-form)
    (define-key map "\C-c.x" 'dune-insert-executables-form)
    (define-key map "\C-c.r" 'dune-insert-rule-form)
    (define-key map "\C-c.p" 'dune-insert-ocamllex-form)
    (define-key map "\C-c.y" 'dune-insert-ocamlyacc-form)
    (define-key map "\C-c.m" 'dune-insert-menhir-form)
    (define-key map "\C-c.a" 'dune-insert-alias-form)
    (define-key map "\C-c.i" 'dune-insert-install-form)
    (define-key map "\C-c.c" 'dune-insert-copyfiles-form)
    (define-key map "\C-c.t" 'dune-insert-tests-form)
    (define-key map "\C-c.v" 'dune-insert-env-form)
    (define-key map "\C-c.d" 'dune-insert-ignored-subdirs-form)
    map)
  "Keymap used in dune mode.")

(defun dune-build-menu ()
  "Build the menu for `dune-mode'."
  (easy-menu-define
    dune-mode-menu  (list dune-mode-map)
    "dune mode menu."
    '("Dune/jbuild"
      ("Stanzas"
       ["library" dune-insert-library-form t]
       ["executable" dune-insert-executable-form t]
       ["executables" dune-insert-executables-form t]
       ["rule" dune-insert-rule-form t]
       ["alias" dune-insert-alias-form t]
       ["ocamllex" dune-insert-ocamllex-form t]
       ["ocamlyacc" dune-insert-ocamlyacc-form t]
       ["menhir" dune-insert-menhir-form t]
       ["install" dune-insert-install-form t]
       ["copy_files" dune-insert-copyfiles-form t]
       ["test" dune-insert-test-form t]
       ["env" dune-insert-env-form t]
       ["ignored_subdirs" dune-insert-ignored-subdirs-form t]
       )))
  (easy-menu-add dune-mode-menu))


;;;###autoload
(define-derived-mode dune-mode prog-mode "dune"
  "Major mode to edit dune files.
For customization purposes, use `dune-mode-hook'."
  (set (make-local-variable 'comment-start) ";")
  (set (make-local-variable 'comment-end) "")
  (setq indent-tabs-mode nil)
  (set (make-local-variable 'require-final-newline) mode-require-final-newline)

  (cond
   ((and dune-use-tree-sitter
         (dune--tree-sitter-available-p))
    ;; Tree-sitter is enabled and available
    ;; First, ensure the grammar is installed
    (dune--ensure-tree-sitter-grammar)

    ;; Now set up tree-sitter mode
    (when (treesit-ready-p 'dune)
      (treesit-parser-create 'dune)
      (setq-local treesit-font-lock-feature-list
                  '((comment string)
                    (keyword builtin property)
                    (type variable constant delimiter)))
      (setq-local treesit-font-lock-settings
                  (apply #'treesit-font-lock-rules
                         dune--treesit-font-lock-rules))
      (setq-local treesit-simple-indent-rules dune--treesit-indent-rules)

      ;; Setup imenu support
      (setq-local treesit-defun-type-regexp "stanza")
      (setq-local treesit-defun-name-function #'dune--treesit-defun-name)

      ;; Setup tree-sitter specific keybindings
      (when (boundp 'dune-mode-map)
        (define-key dune-mode-map (kbd "C-c C-s") #'dune-treesitter-mark-stanza)
        (define-key dune-mode-map (kbd "C-c C-f") #'dune-treesitter-mark-field)
        (define-key dune-mode-map (kbd "C-c C-x") #'dune-treesitter-mark-sexp)
        (define-key dune-mode-map (kbd "C-=") #'dune-treesitter-expand-region))

      ;; Setup tree-sitter flymake backend
      (add-hook 'flymake-diagnostic-functions #'dune-treesitter-flymake-backend nil t)

      (treesit-major-mode-setup)))

   (t
    ;; Fallback to traditional SMIE-based mode
    (set (make-local-variable 'font-lock-defaults) '(dune-font-lock-keywords))
    (smie-setup dune-smie-grammar #'dune-smie-rules)))

  (dune-build-menu))

;;;###autoload
(defun dune-toggle-tree-sitter ()
  "Toggle between tree-sitter and SMIE-based dune-mode.
This command switches the parsing backend and reloads the current buffer's mode."
  (interactive)
  (if (not (dune--tree-sitter-available-p))
      (user-error "Tree-sitter is not available in this Emacs")
    (setq dune-use-tree-sitter (not dune-use-tree-sitter))
    (message "Tree-sitter mode %s. Reloading buffer..."
             (if dune-use-tree-sitter "enabled" "disabled"))
    (dune-mode)))


;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\(?:\\`\\|/\\)dune\\(?:\\.inc\\|\\-project\\|\\-workspace\\)?\\'" . dune-mode))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;                     Interacting with dune

(defcustom dune-command "dune"
  "The dune command."
  :type 'string)

;;;###autoload
(defun dune-promote ()
  "Promote the correction for the current file."
  (interactive)
  (if (buffer-modified-p)
      (error "Cannot promote as buffer is modified")
    (shell-command
     (format
      "%s promote %s" dune-command
      (shell-quote-argument (file-name-nondirectory (buffer-file-name)))))
    (revert-buffer nil t)))

;;;###autoload
(defun dune-runtest-and-promote ()
  "Run tests in the current directory and promote the current buffer."
  (interactive)
  (compile (format "%s build @@runtest" dune-command))
  (dune-promote))

(defun dune-project-p (directory)
  "Return t if DIRECTORY is a dune project."
  (file-exists-p (expand-file-name "dune-project" directory)))

(defun dune-workspace-p (directory)
  "Return t if DIRECTORY is a dune workspace."
  (file-exists-p (expand-file-name "dune-workspace" directory)))

(defun dune-root (&optional directory)
  "Return the root directory of the dune project of DIRECTORY.

DIRECTORY defaults to `default-directory' if not provided."
  (let*
      (root
       workspace
       (dir (or directory default-directory))
       (project-p (lambda (dir)
		    (cond
		     ((dune-workspace-p dir)
		      (setq workspace t)
		      t)
		     ((and
		       (not workspace)
		       (dune-project-p dir))
		      t)))))
    (while dir
      (setq dir (locate-dominating-file dir project-p))
      (when dir
	(setq root dir
	      dir (file-name-parent-directory dir))))
    root))

(provide 'dune)

;;; dune.el ends here

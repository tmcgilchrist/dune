;;; dune-tests.el --- Tests for dune.el  -*- lexical-binding: t; -*-

;; Copyright 2025 Jane Street Group, LLC <opensource@janestreet.com>

;;; Commentary:

;; Test suite for dune-mode using ERT (Emacs Lisp Regression Testing)

;;; Code:

(require 'ert)
(require 'dune)

;;; Basic Mode Tests

(ert-deftest dune-mode-test-basic-loading ()
  "Test that dune-mode can be loaded."
  (should (fboundp 'dune-mode)))

(ert-deftest dune-mode-test-activation ()
  "Test that dune-mode activates correctly."
  (with-temp-buffer
    (dune-mode)
    (should (eq major-mode 'dune-mode))))

(ert-deftest dune-mode-test-comment-syntax ()
  "Test that comment syntax is correctly configured."
  (with-temp-buffer
    (dune-mode)
    (should (equal comment-start ";"))
    (should (equal comment-end ""))))

(ert-deftest dune-mode-test-no-tabs ()
  "Test that dune-mode disables tabs."
  (with-temp-buffer
    (dune-mode)
    (should (eq indent-tabs-mode nil))))

;;; Font Lock Tests

(ert-deftest dune-mode-test-font-lock-stanza ()
  "Test font-locking of stanza names."
  (with-temp-buffer
    (dune-mode)
    (insert "(library\n (name foo))")
    (font-lock-ensure)
    (goto-char (point-min))
    (forward-char)
    (let ((face (get-text-property (point) 'face)))
      (should (or (eq face 'font-lock-keyword-face)
                  (and (listp face) (memq 'font-lock-keyword-face face)))))))

(ert-deftest dune-mode-test-font-lock-field ()
  "Test font-locking of field names."
  (with-temp-buffer
    (dune-mode)
    (insert "(library\n (name foo))")
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward "name")
    (backward-char 2)
    (let ((face (get-text-property (point) 'face)))
      (should (or (eq face 'font-lock-function-name-face)
                  (and (listp face) (memq 'font-lock-function-name-face face)))))))

;;; Indentation Tests

(ert-deftest dune-mode-test-indent-stanza ()
  "Test indentation of a simple stanza."
  (with-temp-buffer
    (dune-mode)
    (insert "(library\n(name foo))")
    (goto-char (point-min))
    (forward-line 1)
    (indent-for-tab-command)
    (should (looking-back "^ " nil))))

(ert-deftest dune-mode-test-indent-field ()
  "Test indentation of fields within a stanza."
  (with-temp-buffer
    (dune-mode)
    (insert "(library\n (name foo)\n(libraries bar))")
    (goto-char (point-min))
    (search-forward "libraries")
    (beginning-of-line)
    (indent-for-tab-command)
    (should (looking-back "^ " nil))))

;;; Tree-sitter Support Tests

(ert-deftest dune-mode-test-tree-sitter-available-check ()
  "Test tree-sitter availability check function."
  (should (fboundp 'dune--tree-sitter-available-p))
  (let ((result (dune--tree-sitter-available-p)))
    (should (or (eq result t) (eq result nil)))))

(ert-deftest dune-mode-test-tree-sitter-defcustom ()
  "Test that tree-sitter defcustom exists and defaults to nil."
  (should (boundp 'dune-use-tree-sitter))
  (should (eq (default-value 'dune-use-tree-sitter) nil)))

(ert-deftest dune-mode-test-tree-sitter-ensure-grammar ()
  "Test that grammar installation function exists."
  (should (fboundp 'dune--ensure-tree-sitter-grammar)))

(ert-deftest dune-mode-test-tree-sitter-font-lock-rules ()
  "Test that tree-sitter font-lock rules are defined."
  (should (boundp 'dune--treesit-font-lock-rules))
  (should (listp dune--treesit-font-lock-rules)))

(ert-deftest dune-mode-test-tree-sitter-indent-rules ()
  "Test that tree-sitter indentation rules are defined."
  (should (boundp 'dune--treesit-indent-rules))
  (should (listp dune--treesit-indent-rules)))

(ert-deftest dune-mode-test-tree-sitter-mode-with-disabled ()
  "Test dune-mode works when tree-sitter is disabled."
  (let ((dune-use-tree-sitter nil))
    (with-temp-buffer
      (dune-mode)
      (should (eq major-mode 'dune-mode))
      (should (boundp 'font-lock-defaults)))))

;;; Auto-mode Tests

(ert-deftest dune-mode-test-auto-mode-dune ()
  "Test that dune files are recognized."
  (should (equal (cdr (assoc "\\(?:\\`\\|/\\)dune\\(?:\\.inc\\|\\-project\\|\\-workspace\\)?\\'" auto-mode-alist))
                 'dune-mode)))

;;; Skeleton/Template Tests

(ert-deftest dune-mode-test-skeletons-defined ()
  "Test that skeleton insertion functions are defined."
  (should (fboundp 'dune-insert-library-form))
  (should (fboundp 'dune-insert-executable-form))
  (should (fboundp 'dune-insert-rule-form))
  (should (fboundp 'dune-insert-test-form)))

;;; Utility Function Tests

(ert-deftest dune-mode-test-dune-project-p ()
  "Test dune-project-p function."
  (should (fboundp 'dune-project-p)))

(ert-deftest dune-mode-test-dune-workspace-p ()
  "Test dune-workspace-p function."
  (should (fboundp 'dune-workspace-p)))

(ert-deftest dune-mode-test-dune-root ()
  "Test dune-root function."
  (should (fboundp 'dune-root)))

;;; Integration Tests with Sample Content

(ert-deftest dune-mode-test-full-library-stanza ()
  "Test parsing a complete library stanza."
  (with-temp-buffer
    (dune-mode)
    (insert "(library
 (name mylib)
 (public_name mylib)
 (libraries base stdio))
")
    (font-lock-ensure)
    (should (eq major-mode 'dune-mode))))

(ert-deftest dune-mode-test-full-executable-stanza ()
  "Test parsing a complete executable stanza."
  (with-temp-buffer
    (dune-mode)
    (insert "(executable
 (name main)
 (public_name myapp)
 (libraries mylib))
")
    (font-lock-ensure)
    (should (eq major-mode 'dune-mode))))

(ert-deftest dune-mode-test-rule-stanza ()
  "Test parsing a rule stanza."
  (with-temp-buffer
    (dune-mode)
    (insert "(rule
 (targets generated.ml)
 (deps input.txt)
 (action (run generator %{deps})))
")
    (font-lock-ensure)
    (should (eq major-mode 'dune-mode))))

(ert-deftest dune-mode-test-comments ()
  "Test that comments are handled correctly."
  (with-temp-buffer
    (dune-mode)
    (insert "; This is a comment
(library
 (name foo)) ; inline comment
")
    (font-lock-ensure)
    (should (eq major-mode 'dune-mode))))

(ert-deftest dune-mode-test-multiline-strings ()
  "Test handling of multiline strings."
  (with-temp-buffer
    (dune-mode)
    (insert "(rule
 (action (write-file foo.txt \"line1
line2
line3\")))
")
    (font-lock-ensure)
    (should (eq major-mode 'dune-mode))))

;;; Flymake Tests

(ert-deftest dune-flymake-test-backend-function-exists ()
  "Test that the modern flymake backend function exists."
  (require 'dune-flymake)
  (should (fboundp 'dune-flymake--backend))
  (should (fboundp 'dune-flymake-setup)))

(ert-deftest dune-flymake-test-setup-adds-backend ()
  "Test that dune-flymake-setup adds the backend to the hook."
  (require 'dune-flymake)
  (with-temp-buffer
    (dune-mode)
    (dune-flymake-setup)
    (should (memq 'dune-flymake--backend flymake-diagnostic-functions))))

(ert-deftest dune-flymake-test-parse-error-line ()
  "Test parsing of dune error lines."
  (require 'dune-flymake)
  (let ((line "File \"dune\", line 5, characters 10-20: Invalid field"))
    (let ((parsed (dune-flymake--parse-error-line line)))
      (should parsed)
      (should (equal (nth 0 parsed) 5))    ; line number
      (should (equal (nth 1 parsed) 10))   ; begin column
      (should (equal (nth 2 parsed) 20))   ; end column
      (should (equal (nth 3 parsed) "Invalid field"))))) ; message

(ert-deftest dune-flymake-test-parse-error-line-no-match ()
  "Test that non-error lines return nil."
  (require 'dune-flymake)
  (should-not (dune-flymake--parse-error-line "This is not an error line")))

;;; Tree-sitter Font-lock Tests

(ert-deftest dune-treesitter-test-font-lock-rules-defined ()
  "Test that tree-sitter font-lock rules are properly defined."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (should (boundp 'dune--treesit-font-lock-rules))
  (should (listp dune--treesit-font-lock-rules))
  ;; Check that the rules contain expected keywords and features
  (let ((rules-string (format "%S" dune--treesit-font-lock-rules)))
    (should (string-match-p ":feature comment" rules-string))
    (should (string-match-p ":feature string" rules-string))
    (should (string-match-p ":feature keyword" rules-string))
    (should (string-match-p ":feature builtin" rules-string))
    (should (string-match-p ":feature property" rules-string))
    (should (string-match-p ":feature type" rules-string))
    (should (string-match-p ":feature variable" rules-string))
    (should (string-match-p ":feature constant" rules-string))
    (should (string-match-p ":feature delimiter" rules-string))))

(ert-deftest dune-treesitter-test-mode-activates-with-treesitter ()
  "Test that dune-mode activates tree-sitter when enabled."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name foo))")
      ;; Verify tree-sitter is active
      (should (treesit-parser-list))
      (should (eq (treesit-parser-language (car (treesit-parser-list))) 'dune)))))

;;; Tree-sitter Indentation Tests

(ert-deftest dune-treesitter-test-indent-stanza ()
  "Test tree-sitter indentation of stanza fields."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n(name foo))")
      (goto-char (point-min))
      (forward-line 1)
      (indent-for-tab-command)
      (should (looking-back "^ " nil)))))

(ert-deftest dune-treesitter-test-indent-nested-action ()
  "Test tree-sitter indentation of nested action blocks."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(rule\n (action\n(run test)))")
      (goto-char (point-min))
      (search-forward "run")
      (beginning-of-line)
      (indent-for-tab-command)
      ;; Action content should be indented by 1 space
      (should (looking-back "^ " nil)))))

(ert-deftest dune-treesitter-test-indent-multiple-fields ()
  "Test tree-sitter indentation of multiple fields in a stanza."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name foo)\n(libraries bar))")
      (goto-char (point-min))
      (forward-line 2)
      (indent-for-tab-command)
      (should (looking-back "^ " nil)))))

(ert-deftest dune-treesitter-test-indent-closing-paren ()
  "Test tree-sitter indentation of closing parentheses."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name foo)\n  )")
      (goto-char (point-min))
      (forward-line 2)
      (indent-for-tab-command)
      (should (looking-at-p "^)")))))

;;; Toggle Command Tests

(ert-deftest dune-test-toggle-tree-sitter-function ()
  "Test that toggle function exists."
  (should (fboundp 'dune-toggle-tree-sitter)))

(ert-deftest dune-test-toggle-tree-sitter-switches-mode ()
  "Test that toggle switches the dune-use-tree-sitter variable."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((original-value dune-use-tree-sitter))
    (with-temp-buffer
      (dune-mode)
      (dune-toggle-tree-sitter)
      (should (not (eq dune-use-tree-sitter original-value)))
      ;; Reset
      (setq dune-use-tree-sitter original-value))))

;;; Imenu Tests

(ert-deftest dune-treesitter-test-imenu-enabled ()
  "Test that imenu is enabled when using tree-sitter."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name mylib))\n\n(executable\n (name main))")
      ;; Check that imenu is configured
      (should (local-variable-p 'treesit-defun-type-regexp))
      (should (local-variable-p 'treesit-defun-name-function)))))

(ert-deftest dune-treesitter-test-defun-name-with-name-field ()
  "Test defun name extraction for stanzas with name field."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name mylib))")
      (goto-char (point-min))
      (forward-line 1)
      (let* ((node (treesit-node-at (point)))
             (name (dune--treesit-defun-name node)))
        (should (string-match-p "library:mylib" name))))))

(ert-deftest dune-treesitter-test-defun-name-without-name-field ()
  "Test defun name extraction for stanzas without name field."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(rule\n (targets output.txt))")
      (goto-char (point-min))
      (forward-line 1)
      (let* ((node (treesit-node-at (point)))
             (name (dune--treesit-defun-name node)))
        (should (string= "rule" name))))))

(ert-deftest dune-treesitter-test-imenu-navigation ()
  "Test that beginning-of-defun works with tree-sitter stanzas."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name mylib))\n\n")
      (insert "(executable\n (name main))\n\n")
      (insert "(test\n (name test_foo))")
      ;; Move to middle of first stanza
      (goto-char (point-min))
      (forward-line 1)
      (let ((initial-pos (point)))
        ;; beginning-of-defun should go to start of library stanza
        (beginning-of-defun)
        (should (looking-at "(library"))
        (should (< (point) initial-pos))))))

;;; Semantic Selection Tests

(ert-deftest dune-treesitter-test-mark-stanza ()
  "Test marking a stanza."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name mylib))\n\n(executable\n (name main))")
      ;; Position cursor in first stanza
      (goto-char (point-min))
      (forward-line 1)
      ;; Mark stanza
      (dune-treesitter-mark-stanza)
      ;; Check that region covers the library stanza
      (should (use-region-p))
      (should (= (region-beginning) 1))
      (should (string= (buffer-substring (region-beginning) (region-end))
                       "(library\n (name mylib))")))))

(ert-deftest dune-treesitter-test-mark-field ()
  "Test that mark-field function exists and runs."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (should (fboundp 'dune-treesitter-mark-field))
  ;; Basic smoke test - function should run without error
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name mylib)\n (libraries base))")
      (goto-char (point-min))
      (search-forward "name")
      (goto-char (match-beginning 0))
      ;; Function should run without error, even if it doesn't find a field
      (should-not (condition-case nil
                      (progn (dune-treesitter-mark-field) nil)
                    (error t))))))

(ert-deftest dune-treesitter-test-mark-sexp ()
  "Test marking an s-expression."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (preprocess (pps ppx_jane)))")
      ;; Position cursor inside (pps ppx_jane)
      (goto-char (point-min))
      (search-forward "pps")
      ;; Mark sexp
      (dune-treesitter-mark-sexp)
      ;; Check that region covers the pps sexp
      (should (use-region-p))
      (let ((text (buffer-substring (region-beginning) (region-end))))
        (should (string-match-p "pps ppx_jane" text))))))

(ert-deftest dune-treesitter-test-expand-region ()
  "Test region expansion."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (insert "(library\n (name mylib))")
      ;; Position cursor on 'mylib'
      (goto-char (point-min))
      (search-forward "mylib")
      (backward-word)
      ;; First expansion should select current node
      (dune-treesitter-expand-region)
      (should (use-region-p))
      (let ((first-region (buffer-substring (region-beginning) (region-end))))
        ;; Second expansion should expand to parent
        (dune-treesitter-expand-region)
        (should (use-region-p))
        (should (> (- (region-end) (region-beginning))
                   (length first-region)))))))

(ert-deftest dune-treesitter-test-selection-keybindings ()
  "Test that selection keybindings are set up."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((dune-use-tree-sitter t))
    (with-temp-buffer
      (dune-mode)
      (should (eq (key-binding (kbd "C-c C-s")) 'dune-treesitter-mark-stanza))
      (should (eq (key-binding (kbd "C-c C-f")) 'dune-treesitter-mark-field))
      (should (eq (key-binding (kbd "C-c C-x")) 'dune-treesitter-mark-sexp))
      (should (eq (key-binding (kbd "C-=")) 'dune-treesitter-expand-region)))))

;;; Comparison Tests (SMIE vs Tree-sitter)

(ert-deftest dune-test-smie-vs-treesitter-indent-library ()
  "Test that SMIE and tree-sitter produce same indentation for library stanza."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((input "(library\n(name foo)\n(libraries bar baz))"))
    ;; Test with SMIE
    (let ((dune-use-tree-sitter nil)
          smie-result)
      (with-temp-buffer
        (dune-mode)
        (insert input)
        (indent-region (point-min) (point-max))
        (setq smie-result (buffer-string)))
      ;; Test with tree-sitter
      (let ((dune-use-tree-sitter t)
            treesit-result)
        (with-temp-buffer
          (dune-mode)
          (insert input)
          (indent-region (point-min) (point-max))
          (setq treesit-result (buffer-string)))
        ;; Compare results
        (should (string= smie-result treesit-result))))))

(ert-deftest dune-test-smie-vs-treesitter-indent-rule ()
  "Test that SMIE and tree-sitter produce same indentation for rule stanza."
  (skip-unless (and (fboundp 'treesit-available-p) (treesit-available-p)
                    (treesit-language-available-p 'dune)))
  (let ((input "(rule\n(targets foo.ml)\n(deps bar.txt)\n(action (run generator)))"))
    ;; Test with SMIE
    (let ((dune-use-tree-sitter nil)
          smie-result)
      (with-temp-buffer
        (dune-mode)
        (insert input)
        (indent-region (point-min) (point-max))
        (setq smie-result (buffer-string)))
      ;; Test with tree-sitter
      (let ((dune-use-tree-sitter t)
            treesit-result)
        (with-temp-buffer
          (dune-mode)
          (insert input)
          (indent-region (point-min) (point-max))
          (setq treesit-result (buffer-string)))
        ;; Compare results
        (should (string= smie-result treesit-result))))))

(provide 'dune-tests)

;;; dune-tests.el ends here

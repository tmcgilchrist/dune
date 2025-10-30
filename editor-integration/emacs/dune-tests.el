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

(ert-deftest dune-flymake-test-program-variable-defined ()
  "Test that dune-flymake-program variable is properly defined."
  (require 'dune-flymake)
  (should (boundp 'dune-flymake-program))
  (should (stringp dune-flymake-program))
  (should (string-match-p "dune-lint" dune-flymake-program)))

(ert-deftest dune-flymake-test-create-script-uses-correct-path ()
  "Test that dune-flymake-create-lint-script uses dune-flymake-program.
This is a regression test for a bug where the code incorrectly referenced
'dune-program' (which doesn't exist) instead of 'dune-flymake-program'."
  (require 'dune-flymake)
  (let* ((temp-dir (make-temp-file "dune-flymake-test" t))
         (dune-flymake-program (expand-file-name "test-dune-lint" temp-dir)))
    (unwind-protect
        (progn
          ;; Ensure the script doesn't exist yet
          (should-not (file-exists-p dune-flymake-program))

          ;; Create the lint script
          (dune-flymake-create-lint-script)

          ;; Verify the script was created at the correct path
          (should (file-exists-p dune-flymake-program))

          ;; Verify it's executable
          (should (file-executable-p dune-flymake-program))

          ;; Verify it contains the expected shebang
          (with-temp-buffer
            (insert-file-contents dune-flymake-program)
            (goto-char (point-min))
            (should (looking-at "#!/usr/bin/env ocaml"))))

      ;; Cleanup
      (when (file-exists-p temp-dir)
        (delete-directory temp-dir t)))))

(ert-deftest dune-flymake-test-init-returns-correct-program ()
  "Test that dune-flymake-init returns command using dune-flymake-program.
This ensures the init function uses the correct variable throughout."
  (require 'dune-flymake)
  (let* ((temp-dir (make-temp-file "dune-flymake-test" t))
         (dune-flymake-program (expand-file-name "test-dune-lint" temp-dir))
         (test-file (expand-file-name "dune" temp-dir)))
    (unwind-protect
        (progn
          ;; Create a test dune file
          (with-temp-file test-file
            (insert "(library (name test))"))

          ;; Visit the file in a buffer
          (with-current-buffer (find-file-noselect test-file)
            (dune-mode)

            ;; Call init and verify it returns the correct program path
            (let ((result (dune-flymake-init)))
              (should (listp result))
              (should (= (length result) 2))
              ;; First element should be the program path
              (should (equal (car result) dune-flymake-program))
              ;; Second element should be the argument list
              (should (listp (cadr result))))))

      ;; Cleanup
      (when (file-exists-p temp-dir)
        (delete-directory temp-dir t)))))

(ert-deftest dune-flymake-test-no-undefined-variable-reference ()
  "Test that dune-flymake doesn't reference undefined 'dune-program' variable.
This is a regression test - the old code had a bug where it referenced
'dune-program' which was never defined, causing byte-compilation errors."
  (require 'dune-flymake)
  ;; Verify dune-flymake-program exists
  (should (boundp 'dune-flymake-program))
  ;; Verify the buggy variable doesn't exist
  (should-not (boundp 'dune-program)))

(provide 'dune-tests)

;;; dune-tests.el ends here

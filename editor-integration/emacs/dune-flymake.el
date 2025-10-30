;;; dune-flymake.el --- Flymake support for dune files   -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright 2017- Christophe Troestler
;; URL: https://github.com/ocaml/dune
;; Version: 1.0
;; Package-Requires: ((emacs "26.3"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This package complements the dune mode with on the fly tests to
;; pinpoint errors.
;;
;; NOTE: This uses the legacy Flymake API (flymake-proc) from Emacs 26+.
;; The Flymake API was redesigned in Emacs 26.1 (May 2018). This code
;; uses the old API for backward compatibility.
;;
;; TODO: Modernize to the new Flymake API
;; The modern API (introduced in Emacs 26.1) uses flymake-diagnostic-functions
;; instead of flymake-allowed-file-name-masks and flymake-err-line-patterns.
;; This would:
;; - Remove dependency on the legacy flymake-proc module
;; - Provide better integration with modern Flymake features
;; - Eliminate byte-compilation warnings about free variables
;; - Allow multiple diagnostic sources simultaneously
;;
;; For reference: https://www.gnu.org/software/emacs/manual/html_mono/flymake.html

;; Permission to use, copy, modify, and distribute this software for
;; any purpose with or without fee is hereby granted, provided that
;; the above copyright notice and this permission notice appear in
;; all copies.
;;
;; THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
;; WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS.  IN NO EVENT SHALL THE
;; AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
;; CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
;; LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
;; NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
;; CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

(require 'flymake)
(require 'dune)

;;; Code:

(defvar-local dune-flymake--process nil
  "The flymake process for the current buffer.")

(defun dune-flymake--find-dune-root ()
  "Find the dune project root for the current buffer."
  (when buffer-file-name
    (or (locate-dominating-file buffer-file-name "dune-project")
        (locate-dominating-file buffer-file-name "dune-workspace")
        default-directory)))

(defun dune-flymake--parse-error-line (line)
  "Parse a dune error LINE and return (LINE-NUM BEG-COL END-COL MESSAGE) or nil."
  (when (string-match
         "File \"[^\"]*\\(dune\\)\", line \\([0-9]+\\), characters \\([0-9]+\\)-\\([0-9]+\\): *\\(.*\\)$"
         line)
    (list (string-to-number (match-string 2 line))
          (string-to-number (match-string 3 line))
          (string-to-number (match-string 4 line))
          (match-string 5 line))))

(defun dune-flymake--make-diagnostics (source-buffer output)
  "Parse dune OUTPUT and create Flymake diagnostics for SOURCE-BUFFER."
  (with-current-buffer source-buffer
    (save-excursion
      (let ((diagnostics '())
            (lines (split-string output "\n" t)))
        (dolist (line lines)
          (when-let ((parsed (dune-flymake--parse-error-line line)))
            (let ((line-num (nth 0 parsed))
                  (beg-col (nth 1 parsed))
                  (end-col (nth 2 parsed))
                  (message (nth 3 parsed)))
              (goto-char (point-min))
              (forward-line (1- line-num))
              (let ((line-beg (line-beginning-position))
                    (line-end (line-end-position)))
                ;; Calculate actual buffer positions from line and column
                (let ((beg (min (+ line-beg beg-col) line-end))
                      (end (min (+ line-beg end-col) line-end)))
                  (when (< beg end)
                    (push (flymake-make-diagnostic
                           source-buffer
                           beg
                           end
                           :error
                           message)
                          diagnostics)))))))
        diagnostics))))

(defun dune-flymake--backend (report-fn &rest _args)
  "Flymake backend for dune files.
REPORT-FN is the callback to report diagnostics."
  (unless (executable-find "dune")
    (funcall report-fn :panic
             :explanation "dune executable not found in PATH"))

  (when (process-live-p dune-flymake--process)
    (kill-process dune-flymake--process))

  (let* ((source-buffer (current-buffer))
         (root (dune-flymake--find-dune-root))
         (filename (file-name-nondirectory (buffer-file-name))))

    (unless root
      (funcall report-fn nil)
      (error "Not in a dune project"))

    (let ((default-directory root))
      (setq dune-flymake--process
            (make-process
             :name "dune-flymake"
             :buffer (generate-new-buffer " *dune-flymake*")
             :command (list "dune" "describe" "external-lib-deps"
                            (concat "--root=" root)
                            filename)
             :connection-type 'pipe
             :sentinel
             (lambda (proc _event)
               (when (eq (process-status proc) 'exit)
                 (unwind-protect
                     (when (buffer-live-p source-buffer)
                       (with-current-buffer source-buffer
                         (let* ((proc-buffer (process-buffer proc))
                                (output (with-current-buffer proc-buffer
                                          (buffer-string))))
                           (if (process-live-p proc)
                               (funcall report-fn :panic
                                        :explanation "Process still running")
                             (let ((diagnostics
                                    (dune-flymake--make-diagnostics
                                     source-buffer output)))
                               (funcall report-fn diagnostics))))))
                   (kill-buffer (process-buffer proc))))))))))

;;;###autoload
(defun dune-flymake-setup ()
  "Enable dune-flymake backend for the current buffer."
  (add-hook 'flymake-diagnostic-functions #'dune-flymake--backend nil t))

(provide 'dune-flymake)

;;; dune-flymake.el ends here

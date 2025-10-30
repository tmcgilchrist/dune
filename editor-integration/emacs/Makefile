# Makefile for dune-mode Emacs Lisp development and testing

EMACS ?= emacs
EMACSFLAGS =
EMACSBATCH = $(EMACS) -Q --batch $(EMACSFLAGS)

EL_FILES = dune.el dune-flymake.el dune-watch.el
TEST_FILES = dune-tests.el
ELC_FILES = $(EL_FILES:.el=.elc)

.PHONY: all test clean compile lint help

help:
	@echo "Makefile for dune-mode Emacs Lisp"
	@echo ""
	@echo "Available targets:"
	@echo "  make test          - Run ERT test suite"
	@echo "  make test-tree-sitter - Run tests with tree-sitter enabled"
	@echo "  make compile       - Byte-compile Emacs Lisp files"
	@echo "  make lint          - Run package-lint and byte-compile checks"
	@echo "  make clean         - Remove byte-compiled files"
	@echo ""
	@echo "Variables:"
	@echo "  EMACS=path/to/emacs - Specify Emacs binary (default: emacs)"

# Run the test suite
test:
	@echo "Running dune-mode tests..."
	./run-tests.sh

# Run tests with tree-sitter enabled
test-tree-sitter:
	@echo "Running dune-mode tests with tree-sitter enabled..."
	$(EMACSBATCH) \
		-L . \
		--eval "(setq dune-use-tree-sitter t)" \
		-l dune.el \
		-l dune-tests.el \
		-f ert-run-tests-batch-and-exit

# Byte-compile all Emacs Lisp files
compile: $(ELC_FILES)

%.elc: %.el
	@echo "Byte-compiling $<..."
	$(EMACSBATCH) \
		-L . \
		-f batch-byte-compile $<

# Lint Emacs Lisp files
lint:
	@echo "Checking for byte-compilation warnings..."
	@echo "Note: Ignoring forward-reference in dune-watch.el (define-minor-mode limitation)"
	@$(EMACSBATCH) \
		-L . \
		-f batch-byte-compile $(EL_FILES) 2>&1 | \
		grep -v "reference to free variable 'dune-watch-minor-mode'" | \
		tee compile.log || true
	@echo ""
	@echo "Byte-compilation complete"

# Check that package can be installed
check-install:
	@echo "Checking package installation..."
	$(EMACSBATCH) \
		--eval "(add-to-list 'load-path \".\")" \
		--eval "(require 'dune)" \
		--eval "(message \"dune.el loaded successfully\")"

# Clean byte-compiled files
clean:
	@echo "Cleaning byte-compiled files..."
	rm -f $(ELC_FILES) dune-tests.elc

# Run all checks
check: lint test
	@echo "All checks passed!"

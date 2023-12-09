SRCDIR 	= ./src
DEPS 	= $(wildcard $(SRCDIR)/*.jl)
TEST 	= ./test/runtests.jl
DOCS 	= $(wildcard ./docs/src/*.md)
DOC 	= ./docs/make.jl

.PHONY: all
all: test doc

test: $(DEPS) $(TEST)
	julia --project=. $(TEST)

doc: $(DEPS) $(DOCS) $(DOC)
	julia --project=. $(DOC)


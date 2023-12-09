SRCDIR 	= ./src
DEPS 	= $(wildcard $(SRCDIR)/*.jl)
TEST 	= ./test/runtests.jl
DOCS 	= $(wildcard ./docs/src/*.md)
DOC 	= ./docs/make.jl

.PHONY: all
all: test doc

test: $(TEST) $(DEPS)
	julia --project=. $(TEST)

doc: $(DOC) $(DOCS) $(DEPS)
	julia --project=. $(DOC)


SRCDIR 	= ./src
DEPS 	= $(wildcard $(SRCDIR)/*.jl)
TEST 	= ./test/runtests.jl
DOCS 	= $(wildcard ./docs/src/*.md)
DOC 	= ./docs/make.jl

.PHONY: all
all: test doc

.PHONY: test
test: $(TEST) $(DEPS)
	julia --project=. $(TEST)

.PHONY: doc
doc: $(DOC) $(DOCS) $(DEPS)
	julia --project=. $(DOC)

.PHONY: repl
repl: FORCE
	julia -i --project=. -e 'using Caper;'

FORCE: ;

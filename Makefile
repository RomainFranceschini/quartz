release ?= ## Compile in release mode
stats ?=   ## Enable statistics output
threads ?= ## Maximum number of threads to use
debug ?=   ## Add symbolic debug info
no-debug ?= ## No symbolic debug info
verbose ?= ## Run specs in verbose mode
link-flags ?= ## Additional flags to pass to the linker

OS := $(shell uname -s | tr '[:upper:@]' '[:lower:]')

O := build

FLAGS := $(if $(release),--release )$(if $(stats),--stats )$(if $(threads),--threads $(threads) )$(if $(debug),-d )$(if $(no-debug),--no-debug )$(if $(link-flags),--link-flags "$(link-flags)" )
VERBOSE := $(if $(verbose),-v )

#EXAMPLES_SOURCES := $(shell find examples -name '*.cr')
EXAMPLES_SOURCES := $(shell git ls-files "examples/*.cr")
EXAMPLES_TARGETS := $(subst examples, $(O), $(patsubst %.cr, %, $(EXAMPLES_SOURCES)))

#BENCHMARKS_SOURCES := $(shell find benchmarks -name '*.cr')
BENCHMARKS_SOURCES := $(shell git ls-files "benchmarks/*.cr")
BENCHMARKS_TARGETS := $(subst benchmarks, $(O), $(patsubst %.cr, %, $(BENCHMARKS_SOURCES)))

$(EXAMPLES_TARGETS):
	@mkdir -p $(O)
	$(BUILD_PATH) crystal build $(FLAGS) $(addsuffix .cr, $(subst build, examples, $@)) -o $@

$(BENCHMARKS_TARGETS):
	@mkdir -p $(O)
	$(BUILD_PATH) crystal build $(FLAGS) $(addsuffix .cr, $(subst build, benchmarks, $@)) -o $@

.PHONY: doc
doc: ## Generate mpi.cr library documentation
	@echo "Building documentation..."
	$(BUILD_PATH) crystal doc src/quartz.cr

.PHONY: examples
examples: $(EXAMPLES_TARGETS)

.PHONY: benchmarks
benchmarks: $(BENCHMARKS_TARGETS)

.PHONY: spec ## Run specs
spec: examples
	$(BUILD_PATH) crystal spec $(FLAGS)
	sh ci/run-examples.sh

.PHONY: clean
clean: ## Clean up built directories and files
	@echo "Cleaning..."
	rm -rf $(O)
	rm -rf ./doc

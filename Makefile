# Convenience targets for the whole tree; apps build from their own dirs.
SAMPLES := $(wildcard samples/*/Makefile)

all:
	@for m in $(SAMPLES); do $(MAKE) -C $$(dirname $$m) || exit 1; done

setup:
	./setup.sh

selftest:
	tools/selftest.sh

selftest-cf:
	tools/selftest.sh --cf

clean:
	rm -rf build
	@for m in $(SAMPLES); do $(MAKE) -C $$(dirname $$m) clean; done

.PHONY: all setup selftest selftest-cf clean

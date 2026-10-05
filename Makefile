# Note on Ruby/Bundler: `make update-deps` can pull a newer, possibly
# pre-release, Bundler into lib/Gemfile.lock ("BUNDLED WITH"). If the build
# then fails with a Bundler version mismatch, re-pin the lockfile to the
# installed Bundler (check with `bundle -v`):
#
#   cd lib && BUNDLE_PATH=.gems bundle update --bundler=<version> --gemfile="$PWD/Gemfile"
LIBDIR := lib
-include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif

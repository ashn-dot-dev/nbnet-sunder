.POSIX:
.SUFFIXES:
.PHONY: \
	all \
	install \
	uninstall \
	clean

NBNET_REPOURL=https://github.com/nathhB/nbnet.git
NBNET_REPODIR=nbnet
NBNET_VERSION=master

EMCC=emcc
EMCFLAGS=$(CFLAGS)
EMAR=emar

all: nbnet.sunder libnbnet.a libnbnet-web.a nbnet-bundle.js

$(NBNET_REPODIR):
	git clone --single-branch --branch "$(NBNET_VERSION)" "$(NBNET_REPOURL)" "$(NBNET_REPODIR)"

nbnet.sunder: $(NBNET_REPODIR) generate.py
	python3 generate.py $(NBNET_REPODIR)/nbnet.h >nbnet.sunder

# TODO: Ideally we would define of _XOPEN_SOURCE with a value of 700 to bring
# in the POSIX definition of `struct timespec` and related functionality.
# However, using `-D_XOPEN_SOURCE=700` on MacOS fails to bring in the
# definition of `CLOCK_MONOTONIC_RAW`, so we use `-D_GNU_SOURCE` instead.

libnbnet.a: $(NBNET_REPODIR) nbnet.c
	$(CC) $(CFLAGS) -D_GNU_SOURCE -o nbnet.o -c -I $(NBNET_REPODIR) nbnet.c
	ar -rcs $@ nbnet.o

libnbnet-web.a: $(NBNET_REPODIR) nbnet.c
	$(EMCC) $(EMCFLAGS) -D_GNU_SOURCE -o nbnet.o -c -I $(NBNET_REPODIR) nbnet.c
	$(EMAR) -rcs $@ nbnet.o

nbnet-bundle.js: $(NBNET_REPODIR)
	# Requires:
	# 	brew install npm
	# 	npm install -g browserify
	# 	npm install -g @mapbox/node-pre-gyp
	# 	TODO: Fallback native build will fail with `failed to find python`
	# 	error when using `@koush/wrtc` instead of `wrtc` as a nbnet dependency.
	(cd $(NBNET_REPODIR)/net_drivers/webrtc/ && npm install)
	(cd $(NBNET_REPODIR) && browserify net_drivers/webrtc/js/nbnet.js -o $@)
	mv $(NBNET_REPODIR)/$@ $@

install: nbnet.sunder libnbnet.a libnbnet-web.a nbnet-bundle.js
	mkdir -p "$(SUNDER_HOME)/lib/nbnet"
	cp $(NBNET_REPODIR)/nbnet.h "$(SUNDER_HOME)/lib/nbnet"
	cp libnbnet.a "$(SUNDER_HOME)/lib/nbnet"
	cp libnbnet-web.a "$(SUNDER_HOME)/lib/nbnet"
	cp -r $(NBNET_REPODIR)/net_drivers "$(SUNDER_HOME)/lib/nbnet"
	cp nbnet-bundle.js "$(SUNDER_HOME)/lib/nbnet"
	cp nbnet.sunder "$(SUNDER_HOME)/lib/nbnet"

uninstall:
	rm -rf "$(SUNDER_HOME)/lib/nbnet"

clean:
	rm -f \
		nbnet.sunder \
		nbnet.o \
		libnbnet.a \
		libnbnet-web.a \
		nbnet-bundle.js \
		$$(find . -name client) \
		$$(find . -name server) \
		$$(find . -name client.html) \

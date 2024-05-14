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

all: nbnet.sunder libnbnet.a libnbnet-web.a

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
	emcc $(CFLAGS) -D_GNU_SOURCE -o nbnet-web.o -c -I $(NBNET_REPODIR) nbnet.c
	emar -rcs $@ nbnet-web.o

# If missing browserify, run:
#
# 	$ npm install -g browserify
nbnet-bundle.js:
	echo "{ \"dependencies\": { \"nbnet\": \"file:$$(realpath $(NBNET_REPODIR))/net_drivers/webrtc\" } }" >package.json
	npm install
	# Whatever I *was* trying to do here was definitely wrong.
	#browserify $(NBNET_REPODIR)/net_drivers/webrtc/js/nbnet.js -o nbnet-bundle.js

install: nbnet.sunder libnbnet.a
	mkdir -p "$(SUNDER_HOME)/lib/nbnet"
	cp $(NBNET_REPODIR)/nbnet.h "$(SUNDER_HOME)/lib/nbnet"
	cp libnbnet.a "$(SUNDER_HOME)/lib/nbnet"
	cp nbnet.sunder "$(SUNDER_HOME)/lib/nbnet"

install-web: nbnet.sunder libnbnet-web.a nbnet-bundle.js
	mkdir -p "$(SUNDER_HOME)/lib/nbnet"
	cp $(NBNET_REPODIR)/nbnet.h "$(SUNDER_HOME)/lib/nbnet"
	cp libnbnet-web.a "$(SUNDER_HOME)/lib/nbnet"
	cp nbnet.sunder "$(SUNDER_HOME)/lib/nbnet"
	cp nbnet-bundle.js "$(SUNDER_HOME)/lib/nbnet"

uninstall:
	rm -rf "$(SUNDER_HOME)/lib/nbnet"

clean:
	rm -rf \
		nbnet.sunder \
		nbnet.o \
		libnbnet.a \
		nbnet-web.o \
		libnbnet-web.a \
		package.json \
		package-lock.json \
		node_modules \
		$$(find . -name 'client') \
		$$(find . -name 'server') \
		$$(find . -name '*.html')

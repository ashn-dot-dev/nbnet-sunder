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

all: nbnet.sunder libnbnet.a

$(NBNET_REPODIR):
	git clone --single-branch --branch "$(NBNET_VERSION)" "$(NBNET_REPOURL)" "$(NBNET_REPODIR)"

nbnet.sunder: $(NBNET_REPODIR) generate.py
	python3 generate.py $(NBNET_REPODIR)/nbnet.h >nbnet.sunder

libnbnet.a: $(NBNET_REPODIR) nbnet.c
	$(CC) $(CFLAGS) -o nbnet.o -c -I $(NBNET_REPODIR) nbnet.c
	ar -rcs $@ nbnet.o

install: nbnet.sunder libnbnet.a
	mkdir -p "$(SUNDER_HOME)/lib/nbnet"
	cp $(NBNET_REPODIR)/nbnet.h "$(SUNDER_HOME)/lib/nbnet"
	cp libnbnet.a "$(SUNDER_HOME)/lib/nbnet"
	cp nbnet.sunder "$(SUNDER_HOME)/lib/nbnet"

uninstall:
	rm -rf "$(SUNDER_HOME)/lib/nbnet"

clean:
	rm -f \
		nbnet.sunder \
		nbnet.o \
		libnbnet.a \
		$$(find -name client) \
		$$(find -name server)

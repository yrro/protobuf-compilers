SHELL := /bin/bash

GPG := gpg
TAR := tar

.PHONY: all
all::

.PHONY: clean
clean::

all:: stamp-install-protobuf-objc-2.6
clean::
	rm -f stamp-install-protobuf-objc-2.6 stamp-clone-protobuf-objc-2.6
	rm -rf protobuf-objc-2.6{,-{build,install}}

stamp-install-protobuf-objc-2.6: stamp-clone-protobuf-objc-2.6 stamp-install-protobuf-2.6
	rm -rf protobuf-objc-2.6-{build,install}
	mkdir protobuf-objc-2.6-build
	set -e; \
		cd protobuf-objc-2.6-build; \
		CPPFLAGS=-I$(abspath protobuf-2.6-install)/include \
		LDFLAGS=-L$(abspath protobuf-2.6-install)/lib \
			../protobuf-objc-2.6/configure \
				--disable-shared \
				--prefix=$(abspath protobuf-objc-2.6-install) \
				--program-suffix=-2.6; \
		$(MAKE); \
		$(MAKE) install
	touch $@

stamp-clone-protobuf-objc-2.6:
	rm -rf protobuf-objc-2.6
	git clone https://github.com/alexeyxo/protobuf-objc.git protobuf-objc-2.6
	cd protobuf-objc-2.6 && git checkout -q 6b85cce49c53bfc82653e7269fdbac70a057a915
	printf '\nprotoc_gen_objc_LDFLAGS += -all-static\n' >> protobuf-objc-2.6/src/compiler/Makefile.am
	cd protobuf-objc-2.6 && ./autogen.sh
	touch $@

# Params:
#  $1: version tag
#  $2: source archive
define protobuf

all:: stamp-install-protobuf-$1
clean::
	rm -f protoc-$1
	rm -f stamp-install-protobuf-$1 stamp-extract-protobuf-$1
	rm -rf protobuf-$1{,-{build,install}}

stamp-install-protobuf-$1: stamp-extract-protobuf-$1
	rm -rf protobuf-$1-{build,install}
	mkdir protobuf-$1-build
	set -e; \
		cd protobuf-$1-build; \
		../protobuf-$1/*/configure \
			--disable-shared \
			--prefix=$$(abspath protobuf-$1-install) \
			--program-suffix=-$1; \
		$(MAKE); \
		$(MAKE) install
	touch $$@

stamp-extract-protobuf-$1: $2
	rm -rf protobuf-$1
	mkdir protobuf-$1
	$(TAR) xf $2 -C protobuf-$1
	echo 'AM_LDFLAGS += -all-static' >> protobuf-$1/*/src/Makefile.am
	cd protobuf-$1/* && ./autogen.sh
	touch $$@
endef

# Params:
#  $1: URL
#  $2: sha256 hash
define wget
$(notdir $1):
	wget --no-use-server-timestamps -O $(notdir $1).tmp $1
	sha256sum -c <<< '$2 *$(notdir $1).tmp'
	mv $(notdir $1).tmp $(notdir $1)

clean::
	rm -f $(notdir $1)
endef

# Params:
#  $1: output file
#  $2: URL
define dget
$1: keyring.gpg
	if ! dget -du $2; then rm -f $1; exit 1; fi
	if ! dscverify --keyring $$(abspath $$<) $(notdir $2); then rm -f $1; exit 1; fi

clean::
	rm -f $1 $(notdir $2) $(wildcard *.debian.tar.*)
endef

$(eval $(call wget,https://github.com/google/protobuf/releases/download/v2.6.1/protobuf-2.6.1.tar.bz2,ee445612d544d885ae240ffbcbf9267faa9f593b7b101f21d58beceb92661910))
$(eval $(call protobuf,2.6,protobuf-2.6.1.tar.bz2))

$(eval $(call dget,protobuf_2.5.0.orig.tar.gz,http://snapshot.debian.org/archive/debian/20131017T100540Z/pool/main/p/protobuf/protobuf_2.5.0-1.dsc))
$(eval $(call protobuf,2.5,protobuf_2.5.0.orig.tar.gz))

$(eval $(call dget,protobuf_2.4.1.orig.tar.gz,http://snapshot.debian.org/archive/debian/20120617T222233Z/pool/main/p/protobuf/protobuf_2.4.1-3.dsc))
$(eval $(call protobuf,2.4,protobuf_2.4.1.orig.tar.gz))

keyring.gpg: $(wildcard *.key)
	rm -f $@
	cat $^ | $(GPG) --no-auto-check-trustdb --no-default-keyring --keyring $(abspath $@) --import

clean::
	rm -f keyring.gpg{,~}

# vim: ts=4 sts=0 sw=4 noet

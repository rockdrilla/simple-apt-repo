#!/usr/bin/make -f
# SPDX-License-Identifier: Apache-2.0
# (c) 2020-2024, Konstantin Demin

ifeq (,$(WORK_ROOT))
$(error this file is not intended to be ran directly)
endif

###############################################################################

SHELL :=/bin/sh

## already handled by shell script
# MAKEFLAGS +=--no-print-directory
# MAKEFLAGS +=--no-builtin-rules
# MAKEFLAGS +=--no-builtin-variables

define flush_vars=
$(foreach v/v,$(strip $(1)),$(eval unexport $(v/v)))
$(foreach v/v,$(strip $(1)),$(eval override undefine $(v/v)))
endef

$(call flush_vars, LANGUAGE LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE )
$(call flush_vars, LC_MONETARY LC_MESSAGES LC_PAPER LC_NAME LC_ADDRESS )
$(call flush_vars, LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION )
$(call flush_vars, GREP_OPTIONS POSIXLY_CORRECT )

export LC_ALL :=C.UTF-8
export LANG   :=C.UTF-8

###############################################################################

.DEFAULT_GOAL: dummy
.PHONY: dummy
dummy:
	@:

###############################################################################

include _common.mk

name_lc :=$(shell printf '%s' '$(name)' | tr '[:upper:]' '[:lower:]')

keyring_file :=$(name_lc).gpg.asc
keyring_uri  :=$(web)/$(keyring_file)
keyring_dir  :=/etc/apt/keyrings
keyring_path :=$(keyring_dir)/$(keyring_file)

ifeq ($(MAKECMDGOALS),stage2)
include _stage1.mk.d/*
endif

ifeq ($(MAKECMDGOALS),update)
include _stage2.mk
include _common.mk.d/*
endif

ifeq ($(MAKECMDGOALS),deploy)
include _stage2.mk
endif

###############################################################################

%.gz: %
	@gzip -9fk $(<) >/dev/null 2>&1

%.xz: %
	@xz -9fk $(<) >/dev/null 2>&1

%.bz2: %
	@bzip2 -9fk $(<) >/dev/null 2>&1

%.zst: %
	@zstd -9fk $(<) >/dev/null 2>&1

###############################################################################

close_stdin =exec 0<&-
mkdir_for =mkdir -p '$(dir $(1))'

###############################################################################

## output is like this:
##   Sat, 06 Apr 2019 17:20:05 UTC
## compare to RFC 5322:
##   Sat, 06 Apr 2019 17:20:05 +0000
apt_date =$(shell date -u '+%a, %d %b %Y %H:%M:%S %Z' -d @$(1))

date_now =$(call apt_date,$(ts_now))
date_end =$(call apt_date,$(ts_end))

###############################################################################

gpg_sign =gpg --sign --armor --output -

%/InRelease: %/Release
	@$(gpg_sign) --clear-sign  $(<) > $(@)

%/Release.gpg: %/Release
	@$(gpg_sign) --detach-sign $(<) > $(@)

%/apt.sources:
	@:; $(close_stdin) ; $(call mkdir_for,$(@)) ; \
	cat $(sort $(^)) > $(@)

apt.sources:
	@:; $(close_stdin) ; \
	cat $(sort $(^)) > $(@)

$(keyring_file):
	@:; $(close_stdin) ; \
	gpg --export --armor > $(@)

###############################################################################

define rules_component_arch =

ifeq (,$(filter main,$(r/$(1)/$(2)/_)))

$(1)/dists/$(2)/main/apt.sources: $(1)/dists/$(2)/$(3)/apt.sources

$(1)/dists/$(2)/main/source/Sources: $(1)/dists/$(2)/$(3)/source/Sources

$(1)/dists/$(2)/main/source/Release: $(1)/dists/$(2)/$(3)/source/Release

$(1)/dists/$(2)/main/binary-$(4)/Packages: $(1)/dists/$(2)/$(3)/binary-$(4)/Packages

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/main/binary-$(4)/,Release Packages $(foreach x,$(comp_list),Packages.$(x)))

endif

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/$(3)/binary-$(4)/,Release Packages $(foreach x,$(comp_list),Packages.$(x)))

endef

define rules_component =

$(1)/dists/$(2)/apt.sources: $(1)/dists/$(2)/$(3)/apt.sources

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/$(3)/source/,Release Sources $(foreach x,$(comp_list),Sources.$(x)))

$(1)/dists/$(2)/$(3)/apt.sources: | $(1)/dists/$(2)/$(3)/source/Release $$(foreach a,$$(a/$(1)/$(2)/$(3)/_),$(1)/dists/$(2)/$(3)/binary-$$(a)/Release)
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo '# Types: deb' ; \
	echo '# URIs: $$(web)/$(1)' ; \
	echo '# Suites: $(2)' ; \
	echo '# Components: $(3)' ; \
	echo '# Architectures: $$(a/$(1)/$(2)/$(3)/_)' ; \
	echo '## sudo mkdir -p $$(keyring_dir)' ; \
	echo '## sudo curl -sSL -o $$(keyring_path) $$(keyring_uri)' ; \
	echo '# Signed-By: $$(keyring_path)' ; \
	echo

$(1)/dists/$(2)/$(3)/source/Release: $$(addprefix $(1)/dists/$(2)/$(3)/source/,$(foreach x,$(comp_list),Sources.$(x)))
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo 'Archive: $(2)' ; \
	echo 'Origin: $$(name)' ; \
	echo 'Label: $$(name)' ; \
	echo 'Component: $(3)' ; \
	echo 'Architecture: source'

$(1)/dists/$(2)/$(3)/source/Sources: $$(addprefix $(1)/.meta/c/$(2)/$(3)/,$$(i/$(1)/$(2)/$(3)/_src))
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	for i in $$(^) ; do cat $$$$i ; echo ; done

$(1)/dists/$(2)/$(3)/binary-%/Release: $$(addprefix $(1)/dists/$(2)/$(3)/binary-%/,$(foreach x,$(comp_list),Packages.$(x)))
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo 'Archive: $(2)' ; \
	echo 'Origin: $$(name)' ; \
	echo 'Label: $$(name)' ; \
	echo 'Component: $(3)' ; \
	echo 'Architecture: $$(*)'

$(1)/dists/$(2)/$(3)/binary-%/Packages:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	for i in $$(addprefix $(1)/.meta/c/$(2)/$(3)/,$$(foreach h,$$(i/$(1)/$(2)/$(3)/_bin),$$(if $$(filter $$(*),$$(a/$(1)/$(2)/$(3)/$$(h))),$$(h)))) ; do cat "$$$$i" ; echo ; done


$(foreach a,$(a/$(1)/$(2)/$(3)/_), $(eval $(call rules_component_arch,$(1),$(2),$(3),$(a))) )


endef

define rules_distrubution =

$(1)/apt.sources: $(1)/dists/$(2)/apt.sources

$(1)/dists/$(2)/apt.sources: | $$(addprefix $(1)/dists/$(2)/,InRelease Release.gpg)

ifeq (,$(filter main,$(r/$(1)/$(2)/_)))

$(1)/dists/$(2)/apt.sources: $(1)/dists/$(2)/main/apt.sources

$(1)/dists/$(2)/main/apt.sources:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo '# Types: deb' ; \
	echo '# URIs: $$(web)/$(1)' ; \
	echo '# Suites: $(2)' ; \
	echo '# Components: main' ; \
	echo '# Architectures: $$(a/$(1)/$(2)/_)' ; \
	echo '## sudo mkdir -p $$(keyring_dir)' ; \
	echo '## sudo curl -sSL -o $$(keyring_path) $$(keyring_uri)' ; \
	echo '# Signed-By: $$(keyring_path)' ; \
	echo

$(1)/dists/$(2)/main/source/Release:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo 'Archive: $(2)' ; \
	echo 'Origin: $$(name)' ; \
	echo 'Label: $$(name)' ; \
	echo 'Component: main' ; \
	echo 'Architecture: source'

$(1)/dists/$(2)/main/source/Sources:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	for i in $$(^) ; do cat "$$$$i" ; echo ; done

$(1)/dists/$(2)/main/binary-%/Release: $$(addprefix $(1)/dists/$(2)/main/binary-%/,$(foreach x,$(comp_list),Packages.$(x)))
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo 'Archive: $(2)' ; \
	echo 'Origin: $$(name)' ; \
	echo 'Label: $$(name)' ; \
	echo 'Component: main' ; \
	echo 'Architecture: $$(*)'

$(1)/dists/$(2)/main/binary-%/Packages:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ;          \
	for i in $$(^) ; do cat "$$$$i" ; echo ; done

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/main/source/,Release Sources $(foreach x,$(comp_list),Sources.$(x)))

$(1)/dists/$(2)/.head.Release:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo 'Origin: $$(name)' ; \
	echo 'Label: $$(name)' ; \
	echo 'Description: $$(desc)' ; \
	echo 'Suite: $(2)' ; \
	echo 'Codename: $(2)' ; \
	echo 'Architectures: $$(a/$(1)/$(2)/_)' ; \
	echo 'Components: main $$(r/$(1)/$(2)/_)' ; \
	echo 'Date: $$(date_now)' ; \
	echo 'Valid-Until: $$(date_end)'

else

$(1)/dists/$(2)/.head.Release:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	touch $$(@) ; exec >$$(@) ; \
	echo 'Origin: $$(name)' ; \
	echo 'Label: $$(name)' ; \
	echo 'Description: $$(desc)' ; \
	echo 'Suite: $(2)' ; \
	echo 'Codename: $(2)' ; \
	echo 'Architectures: $$(a/$(1)/$(2)/_)' ; \
	echo 'Components: $$(r/$(1)/$(2)/_)' ; \
	echo 'Date: $$(date_now)' ; \
	echo 'Valid-Until: $$(date_end)'

endif

$(1)/dists/$(2)/Release: | $(1)/dists/$(2)/.head.Release

$(1)/dists/$(2)/Release:
	@:; $$(close_stdin) ; $$(call mkdir_for,$$(@)); \
	a=$$$$(mktemp -p "$$(WORK_ROOT)/_tmp.d") ; echo 'MD5Sum:' > "$$$$a" ; \
	b=$$$$(mktemp -p "$$(WORK_ROOT)/_tmp.d") ; echo 'SHA1:'   > "$$$$b" ; \
	c=$$$$(mktemp -p "$$(WORK_ROOT)/_tmp.d") ; echo 'SHA256:' > "$$$$c" ; \
	z=$$$$(mktemp -p "$$(WORK_ROOT)/_tmp.d") ; \
	echo $$(^) | xargs -r -n 1 | sort -uV > "$$$$z" ; \
	while read -r f ; do \
	    s=$$$$(stat -Lc '%s' "$$$$f") ; \
	    k=$$$$(md5sum    -b < "$$$$f" | cut -d ' ' -f 1) ; \
	    l=$$$$(sha1sum   -b < "$$$$f" | cut -d ' ' -f 1) ; \
	    m=$$$$(sha256sum -b < "$$$$f" | cut -d ' ' -f 1) ; \
	    f=$$$$(printf '%s' "$$$$f" | cut -d / -f 4-) ; \
	    printf ' %s %9s %s\n' "$$$$k" "$$$$s" "$$$$f" >> "$$$$a" ; \
	    printf ' %s %9s %s\n' "$$$$l" "$$$$s" "$$$$f" >> "$$$$b" ; \
	    printf ' %s %9s %s\n' "$$$$m" "$$$$s" "$$$$f" >> "$$$$c" ; \
	done < "$$$$z" ; \
	touch $$(@) ; exec >$$(@) ; \
	cat $$(dir $$(@)).head.$$(notdir $$(@)) "$$$$a" "$$$$b" "$$$$c" ; \
	rm -f "$$$$z" "$$$$a" "$$$$b" "$$$$c"


$(foreach c,$(r/$(1)/$(2)/_), $(eval $(call rules_component,$(1),$(2),$(c))) )


endef

define rules_channel =

apt.sources: $(1)/apt.sources

$(foreach d,$(r/$(1)/_), $(eval $(call rules_distrubution,$(1),$(d))) )


endef

ifeq ($(MAKECMDGOALS),update)

$(foreach c/c,$(r/_), $(eval $(call rules_channel,$(c/c))) )

update: apt.sources

endif

###############################################################################

.PHONY: stage2
stage2:
	@exec >_stage2.mk ; \
	$(foreach v/v, \
	  $(sort $(foreach v/v,$(.VARIABLES), \
	    $(if \
	      $(shell printf '%s' '$(v/v)' | grep -Fq '/_' && echo x || true), \
	      $(v/v) \
	    ) \
	  )), \
	  echo '$(v/v) :=$($(v/v))' ; \
	)

###############################################################################

.PHONY: update
update:
	@:

###############################################################################

.PHONY: deploy
deploy: $(keyring_file)
	@:; \
	find '$(WORK_ROOT)/' -xdev -mindepth 1 \
	  -type f -exec chmod 0644 '{}' '+' ; \
	find '$(WORK_ROOT)/' -xdev -mindepth 1 \
	  -type f -exec touch -m -d @$(ts_now) '{}' '+' ; \
	find '$(WORK_ROOT)/' -xdev -mindepth 1 \
	  -type d -exec chmod 0755 '{}' '+' ; \
	find '$(WORK_ROOT)/' -xdev -mindepth 1 \
	  -type d -exec touch -m -d @$(ts_now) '{}' '+' ; \
	for i in $(foreach k,$(r/_),$(addprefix $(k)/,dists .meta)) ; do \
	  mkdir -p $(repo_root)/$$i/ ; \
	  rsync -ca --delete-after $(WORK_ROOT)/$$i/ $(repo_root)/$$i/ ; \
	done ; \
	cp -a apt.sources $(keyring_file) $(repo_root)/

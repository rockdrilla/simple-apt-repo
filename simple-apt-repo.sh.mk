#!/usr/bin/make -f
# SPDX-License-Identifier: BSD-3-Clause
# (c) 2020, Konstantin Demin

ifeq (,$(work_root))
$(error this file is not intended to be ran directly)
endif

###############################################################################

SHELL :=/bin/sh

## already handled by shell script
# MAKEFLAGS +=--no-print-directory
# MAKEFLAGS +=--no-builtin-rules
# MAKEFLAGS +=--no-builtin-variables

define flush_vars=
$(foreach v/v,$(1),$(eval unexport $(v/v)))
$(foreach v/v,$(1),$(eval override undefine $(v/v)))
endef

$(call flush_vars,LANG LANGUAGE LC_ALL LC_COLLATE LC_CTYPE LC_MESSAGES)
$(call flush_vars,LC_NUMERIC LC_TIME POSIXLY_CORRECT GREP_OPTIONS)

export LC_ALL :=C.UTF-8

###############################################################################

.DEFAULT_GOAL: dummy
.PHONY: dummy
dummy:
	@:

###############################################################################

include _common.mk

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
	@gzip -fk $(<) >/dev/null 2>/dev/null

%.xz: %
	@xz -fk $(<) >/dev/null 2>/dev/null

%.bz2: %
	@bzip2 -fk $(<) >/dev/null 2>/dev/null

%.zst: %
	@zstd -fk $(<) >/dev/null 2>/dev/null

###############################################################################

mkdir_p =dirname -z "$(1)" | xargs -0 -r mkdir -p

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

%/sources.list:
	@$(call mkdir_p,$(@)); exec 0<&- ; \
	cat $(sort $(^)) > $(@)

sources.list:
	@exec 0<&- ; \
	cat $(sort $(^)) > $(@)

###############################################################################

define rules_component_arch =

ifeq (,$(filter main,$(r/$(1)/$(2)/_)))

$(1)/dists/$(2)/main/sources.list: $(1)/dists/$(2)/$(3)/sources.list

$(1)/dists/$(2)/main/source/Sources: $(1)/dists/$(2)/$(3)/source/Sources

$(1)/dists/$(2)/main/source/Release: $(1)/dists/$(2)/$(3)/source/Release

$(1)/dists/$(2)/main/binary-$(4)/Packages: $(1)/dists/$(2)/$(3)/binary-$(4)/Packages

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/main/binary-$(4)/,Release Packages $(foreach x,gz xz bz2 zst,Packages.$(x)))

endif

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/$(3)/binary-$(4)/,Release Packages $(foreach x,gz xz bz2 zst,Packages.$(x)))

endef

define rules_component =

$(1)/dists/$(2)/sources.list: $(1)/dists/$(2)/$(3)/sources.list

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/$(3)/source/,Release Sources $(foreach x,gz xz bz2 zst,Sources.$(x)))

$(1)/dists/$(2)/$(3)/sources.list: | $(1)/dists/$(2)/$(3)/source/Release $$(foreach a,$$(a/$(1)/$(2)/$(3)/_),$(1)/dists/$(2)/$(3)/binary-$$(a)/Release)
	@$$(call mkdir_p,$$(@)); exec 0<&- ;     \
	touch $$(@) ; exec 1>$$(@) ;             \
	echo "## arch: $$(a/$(1)/$(2)/$(3)/_)" ; \
	echo "# deb $$(web)/$(1) $(2) $(3)"    ; \
	echo

$(1)/dists/$(2)/$(3)/source/Release: $$(addprefix $(1)/dists/$(2)/$(3)/source/,$(foreach x,gz xz bz2 zst,Sources.$(x)))
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	echo 'Archive: $(2)' ;               \
	echo 'Origin: $$(name)' ;            \
	echo 'Label: $$(name)' ;             \
	echo 'Component: $(3)' ;             \
	echo 'Architecture: source'

$(1)/dists/$(2)/$(3)/source/Sources: $$(addprefix $(1)/.meta/c/$(2)/$(3)/,$$(i/$(1)/$(2)/$(3)/_src))
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	for i in $$(^) ; do cat $$$$i ; echo ; done

$(1)/dists/$(2)/$(3)/binary-%/Release: $$(addprefix $(1)/dists/$(2)/$(3)/binary-%/,$(foreach x,gz xz bz2 zst,Packages.$(x)))
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	echo 'Archive: $(2)' ;               \
	echo 'Origin: $$(name)' ;            \
	echo 'Label: $$(name)' ;             \
	echo 'Component: $(3)' ;             \
	echo 'Architecture: $$(*)'

$(1)/dists/$(2)/$(3)/binary-%/Packages:
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	for i in $$(addprefix $(1)/.meta/c/$(2)/$(3)/,$$(foreach h,$$(i/$(1)/$(2)/$(3)/_bin),$$(if $$(filter $$(*),$$(a/$(1)/$(2)/$(3)/$$(h))),$$(h)))) ; do cat $$$$i ; echo ; done


$(foreach a,$(a/$(1)/$(2)/$(3)/_), $(eval $(call rules_component_arch,$(1),$(2),$(3),$(a))) )


endef

define rules_distrubution =

$(1)/sources.list: $(1)/dists/$(2)/sources.list

$(1)/dists/$(2)/sources.list: | $$(addprefix $(1)/dists/$(2)/,InRelease Release.gpg)

ifeq (,$(filter main,$(r/$(1)/$(2)/_)))

$(1)/dists/$(2)/sources.list: $(1)/dists/$(2)/main/sources.list

$(1)/dists/$(2)/main/sources.list:
	@$$(call mkdir_p,$$(@)); exec 0<&- ;  \
	touch $$(@) ; exec 1>$$(@) ;          \
	echo "## arch: $$(a/$(1)/$(2)/_)" ;   \
	echo "# deb $$(web)/$(1) $(2) main" ; \
	echo

$(1)/dists/$(2)/main/source/Release:
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	echo 'Archive: $(2)' ;               \
	echo 'Origin: $$(name)' ;            \
	echo 'Label: $$(name)' ;             \
	echo 'Component: main' ;             \
	echo 'Architecture: source'

$(1)/dists/$(2)/main/source/Sources:
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	for i in $$(^) ; do cat $$$$i ; echo ; done

$(1)/dists/$(2)/main/binary-%/Release: $$(addprefix $(1)/dists/$(2)/main/binary-%/,$(foreach x,gz xz bz2 zst,Packages.$(x)))
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	echo 'Archive: $(2)' ;               \
	echo 'Origin: $$(name)' ;            \
	echo 'Label: $$(name)' ;             \
	echo 'Component: main' ;             \
	echo 'Architecture: $$(*)'

$(1)/dists/$(2)/main/binary-%/Packages:
	@$$(call mkdir_p,$$(@)); exec 0<&- ; \
	touch $$(@) ; exec 1>$$(@) ;         \
	for i in $$(^) ; do cat $$$$i ; echo ; done

$(1)/dists/$(2)/Release: $$(addprefix $(1)/dists/$(2)/main/source/,Release Sources $(foreach x,gz xz bz2 zst,Sources.$(x)))

$(1)/dists/$(2)/Release.head:
	@$$(call mkdir_p,$$(@)); exec 0<&- ;        \
	touch $$(@) ; exec 1>$$(@) ;                \
	echo 'Origin: $$(name)' ;                   \
	echo 'Label: $$(name)' ;                    \
	echo 'Description: $$(desc)' ;              \
	echo 'Suite: $(2)' ;                        \
	echo 'Codename: $(2)' ;                     \
	echo 'Architectures: $$(a/$(1)/$(2)/_)' ;   \
	echo 'Components: main $$(r/$(1)/$(2)/_)' ; \
	echo 'Date: $$(date_now)' ;                 \
	echo 'Valid-Until: $$(date_end)'

else

$(1)/dists/$(2)/Release.head:
	@$$(call mkdir_p,$$(@)); exec 0<&- ;        \
	touch $$(@) ; exec 1>$$(@) ;                \
	echo 'Origin: $$(name)' ;                   \
	echo 'Label: $$(name)' ;                    \
	echo 'Description: $$(desc)' ;              \
	echo 'Suite: $(2)' ;                        \
	echo 'Codename: $(2)' ;                     \
	echo 'Architectures: $$(a/$(1)/$(2)/_)' ;   \
	echo 'Components: $$(r/$(1)/$(2)/_)' ;      \
	echo 'Date: $$(date_now)' ;                 \
	echo 'Valid-Until: $$(date_end)'

endif

$(1)/dists/$(2)/Release: | $(1)/dists/$(2)/Release.head

$(1)/dists/$(2)/Release:
	@$$(call mkdir_p,$$(@)); exec 0<&- ;                                  \
	a=$$$$(mktemp -p "$$(work_root)/_tmp.d") ; echo 'MD5Sum:' > "$$$$a" ; \
	b=$$$$(mktemp -p "$$(work_root)/_tmp.d") ; echo 'SHA1:'   > "$$$$b" ; \
	c=$$$$(mktemp -p "$$(work_root)/_tmp.d") ; echo 'SHA256:' > "$$$$c" ; \
	z=$$$$(mktemp -p "$$(work_root)/_tmp.d") ;                            \
	echo $$(^) | xargs -r -n 1 | sort -V > "$$$$z" ;                      \
	while read -r f ; do                                                  \
	    s=$$$$(stat -c '%s' "$$$$f") ;                                    \
	    k=$$$$(md5sum    -b < "$$$$f" | cut -d ' ' -f 1) ;                \
	    l=$$$$(sha1sum   -b < "$$$$f" | cut -d ' ' -f 1) ;                \
	    m=$$$$(sha256sum -b < "$$$$f" | cut -d ' ' -f 1) ;                \
	    f=$$$$(echo -n "$$$$f" | cut -d / -f 4-) ;                        \
	    printf ' %s %9s %s\n' "$$$$k" "$$$$s" "$$$$f" >> "$$$$a" ;        \
	    printf ' %s %9s %s\n' "$$$$l" "$$$$s" "$$$$f" >> "$$$$b" ;        \
	    printf ' %s %9s %s\n' "$$$$m" "$$$$s" "$$$$f" >> "$$$$c" ;        \
	done < "$$$$z" ;                                                      \
	touch $$(@) ; exec 1>$$(@) ;                                          \
	cat $$(@).head ; cat "$$$$a" ; cat "$$$$b" ; cat "$$$$c" ;            \
	rm -f "$$$$z" "$$$$a" "$$$$b" "$$$$c"


$(foreach c,$(r/$(1)/$(2)/_), $(eval $(call rules_component,$(1),$(2),$(c))) )


endef

define rules_channel =

sources.list: $(1)/sources.list

$(foreach d,$(r/$(1)/_), $(eval $(call rules_distrubution,$(1),$(d))) )


endef

ifeq ($(MAKECMDGOALS),update)

$(foreach c/c,$(r/_), $(eval $(call rules_channel,$(c/c))) )

update: sources.list

endif

###############################################################################

.PHONY: stage2
stage2:
	@exec 1>_stage2.mk ; \
	$(foreach v/v, \
	  $(sort $(foreach v/v,$(.VARIABLES), \
	    $(if \
	      $(shell echo -n '$(v/v)' | grep -Fq '/_' && echo x || true), \
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
deploy:
	@:; \
	find "$(work_root)/" -xdev -mindepth 1 \
	  -type f -exec chmod 644 '{}' '+' ;   \
	find "$(work_root)/" -xdev -mindepth 1            \
	  -type f -exec touch -m -d @$(ts_now) '{}' '+' ; \
	find "$(work_root)/" -xdev -mindepth 1 \
	  -type d -exec chmod 755 '{}' '+' ;   \
	find "$(work_root)/" -xdev -mindepth 1            \
	  -type d -exec touch -m -d @$(ts_now) '{}' '+' ; \
	for i in $(foreach k,$(r/_),$(addprefix $(k)/,dists .meta)) ; do  \
	  mkdir -p $(repo_root)/$$i/ ;                                   \
	  rsync -ca --delete-after $(work_root)/$$i/ $(repo_root)/$$i/ ; \
	done ;                                                           \
	cp -a sources.list $(repo_root)/

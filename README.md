## About

`simple-apt-repo.sh` is a shell script written to help generate simple (so far) [APT](https://en.wikipedia.org/wiki/APT_(software)) repository for [Debian GNU/Linux](https://en.wikipedia.org/wiki/Debian) distro and it's derivatives.

It's designed to be good for relatively small (IMO?) repositories.

E.g., my own repo (hosted on dual-core VMware-based VM):
- contains about \~200 packages
- consumes about 1.8 Gb,
- full repo rebuild takes about 25 seconds,
- refreshing repo (with \~10% packages added/removed) takes about 15 seconds.

If you're unhappy with this script - try [alternatives](https://wiki.debian.org/DebianRepository/Setup)! :)

## Prerequisites / installation

`simple-apt-repo.sh` requires that you're already installed following packages:
- `make` - GNU Make;
- `findutils` - GNU findutils;
- `gpg` and `gpgconf` - GnuPG (GNU Privacy Guard);
- `xz-utils` - XZ compression utilities;
- `bzip2` - Bzip2 compression utilities;
- `zstd` - ZSTD compression utilities;
- `rsync` - rsync (versatile file-copying tool);
- `file` - file type recognition tool (not really needed by this script, just last-resort tool).

Run following command to fulfill these requirements:
```
sudo apt install make findutils gpg gpgconf xz-utils bzip2 zstd rsync file
```

*There's also a companion script - `simple-apt-repo.sh.mk` - which is special [Makefile](https://en.wikipedia.org/wiki/Make_(software)#Makefile) to deal with recursive recipes and other magic.*

Copy `simple-apt-repo.sh` [[link]](https://github.com/rockdrilla/simple-apt-repo/raw/master/simple-apt-repo.sh)
and `simple-apt-repo.sh.mk` [[link]](https://github.com/rockdrilla/simple-apt-repo/raw/master/simple-apt-repo.sh.mk)
to your preferred location (e.g. `~/bin/`).

Nota bene: only `simple-apt-repo.sh` requires 'executable' bit set:
```
chmod +x /your/preferred/location/simple-apt-repo.sh
```

Hint: you can rename file to whatever you want but also rename helper GNU Make file.

Example: if you wish to rename `simple-apt-repo.sh` to `repo-upd`,
then you'll need to rename `simple-apt-repo.sh.mk` to `repo-upd.mk`.

## Usage

Just run `simple-apt-repo.sh` with no arguments are required...
if you've set up all things already. ;)

At first, set up simple configuration file in shell syntax (it's sourced by `simple-apt-repo.sh`).
This file is stored as `~/.config/simplerepo`.

Example configuration:
```sh
repo_root='/var/www/deb'
name='SimpleAptRepo'
desc='custom Debian packages for folks'
web='http://example.com/deb'
GNUPGHOME='/home/user/.gnupg'
```

Configuration file doesn't require execution bit to be set, leave it with `0644` rights.

Brief overview of variables:
- `repo_root` - REQUIRED: where's your repository is placed (see below *"Filesystem layout"*)
- `name` - REQUIRED: repository origin ([aptitude](https://en.wikipedia.org/wiki/Aptitude_(software)) search/filter syntax like "`~OSimpleAptRepo`")
- `desc` - REQUIRED: repository description
- `web` - REQUIRED: HTTP web root for `repo_root` (set up your web-server accordingly)
- `GNUPGHOME` - optional: home folder for your GnuPG setup (see below *"Few words about GnuPG"*)



## Filesystem layout

`repo_root` is required to be filled like this:

```
$repo_root/
|
-> <channel>/
   |
   -> pool/
      |
      -> <distribution>/
         |
         -> <component>/
            |
            -> <.deb/.dsc files>
```

`channel` is also can be interpreted as `codename` - like `stable` (Debian) or `focal` (Ubuntu).

Example:

Consider `$repo_root` set to `/var/www/deb` and `$web` to `http://example.com/deb`.

We have binary package placed at:

```
/var/www/deb/buster/pool/mongo/3.4/3.4.24-0.2/amd64/mongodb_3.4.24-0.2_amd64.deb
```

From here:
- channel is `buster`
- distribution is `mongo`
- component is `3.4`

Script generates following filesystem tree:

```
/var/www/deb/
|
-> buster/
   |
   -> dists/
      |
      -> mongo/
         |
         -> InRelease
         |
         -> Release
         |
         -> Release.gpg
         |
         -> 3.4/
            |
            -> binary-amd64/
               |
               -> Packages
               |
               -> Packages.gz
               |
               -> Packages.xz
               |
               -> Packages.bz2
               |
               -> Packages.zst
               |
               -> Release
```

Resulting `apt sources` line will be:

```
deb http://example.com/deb/buster mongo 3.4
```

Script also generates 'all-in-one' component `main` for each distribution - if and only if distribution doesn't have such component already.

So you can write `apt sources` line just like this:

```
deb http://example.com/deb/buster mongo main
```

## Implementation details

Script generates/caches some metadata for each `channel` which is stored at `$repo_root/$channel/meta/`.

These files contains only source/binary packages related information,
so it's pretty safe to expose them on the web.

Avoid modifying any of these files, or repository will be logically broken.

In case of trouble - just remove entire `meta/` directory and re-run script.

If this doesn't help - feel free to report issue or send pull request (on GitHub). :)

## Few words about GnuPG

Be sure that you've set up GnuPG for batch/password-less work.

For this case you'll need to create subkeys without password protection or create another keypair.

Just google a bit around phrase 'setting up gnupg subkeys'. :)

Example configuration (`$GNUPGHOME/gpg.conf`):

```
personal-digest-preferences SHA256
cert-digest-algo SHA256
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 ZLIB BZIP2 ZIP Uncompressed

no-greeting
charset utf-8

expert

local-user <YOUR KEYID>!
```

Nota bene: exclamation mark at the end of `<YOUR KEYID>` is mandatory (AFAIK).

## License

BSD 3-Clause
- [spdx.org](https://spdx.org/licenses/BSD-3-Clause.html)
- [opensource.org](https://opensource.org/licenses/BSD-3-Clause)

### Text:

Copyright (c) 2020 Konstantin Demin. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

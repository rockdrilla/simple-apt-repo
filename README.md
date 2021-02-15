## About

`simple-apt-repo.sh` is a shell script written to help generate simple (so far) [APT](https://en.wikipedia.org/wiki/APT_(software)) repository for [Debian GNU/Linux](https://en.wikipedia.org/wiki/Debian) distro and it's derivatives.

It's designed to be good for relatively small (IMO?) repositories.

E.g., my own repo (hosted on dual-core virtual private server):
- contains about \~180 packages
- consumes about 1.5 Gb,
- full repo rebuild takes about 16 seconds,
- refreshing repo (with \~10% packages added/removed) takes about 8 seconds.

If you're unhappy with this script - try [alternatives](https://wiki.debian.org/DebianRepository/Setup)! :)

---

## Prerequisites / installation

### TL;DR (*copy/paste*):

```sh
# install dependencies
sudo apt install make findutils gpg gpgconf xz-utils bzip2 zstd rsync file

# prepare directories
[ -d "$HOME/bin" ]     || { mkdir -p "$HOME/bin" ;     chmod 0755 "$HOME/bin" ; }
[ -d "$HOME/.config" ] || { mkdir -p "$HOME/.config" ; chmod 0700 "$HOME/.config" ; }

# download scripts
curl -L -o "$HOME/bin/update-repo"    https://github.com/rockdrilla/simple-apt-repo/raw/master/simple-apt-repo.sh
curl -L -o "$HOME/bin/update-repo.mk" https://github.com/rockdrilla/simple-apt-repo/raw/master/simple-apt-repo.sh.mk

# set correct permissions for script
chmod a+x "$HOME/bin/update-repo"

# setup default (but not valid) config
[ -f "$HOME/.config/simplerepo" ] || {
cat > "$HOME/.config/simplerepo" <<EOF
repo_root='/var/www/deb'
name='SimpleAptRepo'
desc='custom Debian packages for folks'
web='http://example.com/deb'
GNUPGHOME='$HOME/.gnupg'
EOF
echo "edit your config at '$HOME/.config/simplerepo' appropriately"
}

echo 'installation is done; run script as ~/bin/update-repo'
```

### detailed:

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
```sh
sudo apt install make findutils gpg gpgconf xz-utils bzip2 zstd rsync file
```

Copy `simple-apt-repo.sh` [[link]](https://github.com/rockdrilla/simple-apt-repo/raw/master/simple-apt-repo.sh)
and `simple-apt-repo.sh.mk` [[link]](https://github.com/rockdrilla/simple-apt-repo/raw/master/simple-apt-repo.sh.mk)
to your preferred location (e.g. `~/bin/`).

*`simple-apt-repo.sh.mk` - special companion script ([Makefile](https://en.wikipedia.org/wiki/Make_(software)#Makefile)).*

**Nota bene**: only `simple-apt-repo.sh` requires 'executable' bit set.

---

**Hint**: you can rename file to whatever you want but also rename helper GNU Make file.

Example: if you wish to rename `simple-apt-repo.sh` to `repo-upd`,
then you'll need to rename `simple-apt-repo.sh.mk` to `repo-upd.mk`.

---

**Hint**: symlinks to scripts are working too!

Consider following sample shell snippet:
```sh
# install
git clone https://github.com/rockdrilla/simple-apt-repo.git ~/apt-repo.git
# nota bene: ~/apt-repo.git/simple-apt-repo.sh has 0755 rights already
ln -s ../apt-repo.git/simple-apt-repo.sh    ~/bin/update-repo
ln -s ../apt-repo.git/simple-apt-repo.sh.mk ~/bin/update-repo.mk

# post-install
git -C ~/apt-repo.git config pull.ff only

# update
git -C ~/apt-repo.git pull
```

---

## Usage

Just run `simple-apt-repo.sh` with no arguments are required...
if you've set up all things already. ;)

### Configuration:

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

---

### Setting up your Web-server:

Here's sample scripts for Nginx:
- `aux/nginx.plain.conf` - serve (browsable) repository via (plain) HTTP
- `aux/nginx.ssl.conf` - serve (browsable) repository via (plain) HTTP for [APT](https://en.wikipedia.org/wiki/APT_(software)) and via HTTPS for regular users (*he-he, "regular users"* xD)

---

## Filesystem layout

`$repo_root` is required to be filled like this:

```sh
$repo_root/
|
-> ${channel}/
   |
   -> pool/
      |
      -> ${distribution}/
         |
         -> ${component}/
            |
            -> <.deb/.dsc files>
```

`${channel}` is also can be interpreted as `codename` - like `stable` (Debian) or `focal` (Ubuntu).

### Example

Consider following settings:
```sh
$repo_root = /var/www/deb
$web       = http://example.com/deb
```

We have binary package placed at:

```
/var/www/deb/buster/pool/mongo/3.4/3.4.24-0.2/amd64/mongodb_3.4.24-0.2_amd64.deb
```

Script deduces following statements:
```sh
${channel}      = buster
${distribution} = mongo
${component}    = 3.4
```

Script generates following filesystem tree:

```sh
/var/www/deb/buster/
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

Script also generates 'all-in-one' component `main` for each distribution - **if and only if** distribution doesn't have such component already.

So you can write `apt sources` line just like this:

```
deb http://example.com/deb/buster mongo main
```

---

## Implementation details

Script generates/caches some metadata for each `$channel` which is stored at `$repo_root/$channel/.meta/`.

These files contains only source/binary packages related information,
so it's pretty safe to expose them on the web.

Avoid modifying any of these files, or repository will be logically broken.

In case of trouble - just remove entire `.meta/` directory and re-run script.

If this doesn't help - feel free to report issue or send pull request (on GitHub). :)

---

## Few words about GnuPG

Be sure that you've set up GnuPG for batch/password-less work.

For this case you'll need to create subkeys without password protection or create another keypair.

Just google a bit around phrase `"setting up gnupg subkeys"`. :)

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

---

## License

BSD 3-Clause
- [spdx.org](https://spdx.org/licenses/BSD-3-Clause.html)
- [opensource.org](https://opensource.org/licenses/BSD-3-Clause)

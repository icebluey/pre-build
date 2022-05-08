#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
/sbin/ldconfig >/dev/null 2>&1

umask 022

CFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CFLAGS
CXXFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CXXFLAGS
LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld'
export LDFLAGS

CC=gcc
export CC
CXX=g++
export CXX

_strip_and_zipman () {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib/gnupg2 ]]; then
        find usr/lib/gnupg2/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
}

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

#https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz
_tar_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/tar/' | grep -i 'href="tar-[1-9].*\.tar\.' | sed 's|"|\n|g' | grep -i '^tar-[1-9]' | sed -e 's|tar-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 9 -T 9 "https://ftp.gnu.org/gnu/tar/tar-${_tar_ver}.tar.xz"
sleep 1
tar -xf tar-${_tar_ver}.tar.*
sleep 1
rm -f tar-*.tar*
cd tar-*
sleep 1

./configure \
DEFAULT_ARCHIVE_FORMAT=GNU \
FORCE_UNSAFE_CONFIGURE=1 \
--build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include \
--sysconfdir=/etc --libexecdir=/usr/sbin
sleep 1
make all
sleep 1
rm -fr /tmp/tar
sleep 1
make install DESTDIR=/tmp/tar
sleep 1
cd /tmp/tar/
_strip_and_zipman

echo
sleep 2
tar -Jcvf /tmp/tar-"${_tar_ver}"-1.el7.x86_64.tar.xz *
echo
sleep 2

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/tar
printf '\033[01;32m%s\033[m\n' '  build tar done'
echo
exit


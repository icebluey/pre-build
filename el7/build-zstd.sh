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

#https://github.com/facebook/zstd.git
git clone "https://github.com/facebook/zstd.git"
sleep 1
cd zstd

#find ./ -iname Makefile | xargs -I "{}" sed 's@prefix.*?= /usr/local@prefix      ?= /usr@g' -i "{}"
#sed '/^libdir/s|)/lib$|)/lib64|g' -i lib/Makefile
#sed 's@LIBDIR.*?= $(exec_prefix)/lib$@LIBDIR      ?= $(exec_prefix)/lib64@'  -i lib/Makefile

sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i Makefile
sed '/^prefix/s|= .*|= /usr|g' -i Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i lib/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i lib/Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i programs/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i programs/Makefile

sleep 1
make V=1 all prefix=/usr libdir=/usr/lib64
sleep 1
rm -fr /tmp/zstd
sleep 1
make install DESTDIR=/tmp/zstd
sleep 1
cd /tmp/zstd/
_zstd_ver="$(cat usr/lib64/pkgconfig/libzstd.pc | grep '^Version: ' | awk '{print $NF}')"
sed 's|http:|https:|g' -i usr/lib64/pkgconfig/libzstd.pc
_strip_and_zipman

echo
sleep 2
tar -Jcvf /tmp/zstd-"${_zstd_ver}"-1.el7.x86_64.tar.xz *
echo
sleep 2

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/zstd
printf '\033[01;32m%s\033[m\n' '  build zstd done'
echo
exit


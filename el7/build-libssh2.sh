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

#https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
_libssh2_ver="$(wget -qO- 'https://www.libssh2.org/' | grep 'libssh2-[1-9].*\.tar\.' | sed 's|"|\n|g' | grep -i '^download/libssh2-[1-9]' | sed -e 's|.*libssh2-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc[0-9]' | sort -V | tail -n 1)"
wget -c -t 9 -T 9 "https://www.libssh2.org/download/libssh2-${_libssh2_ver}.tar.gz"
sleep 1
tar -xof libssh2-${_libssh2_ver}.tar.*
sleep 1
rm -f libssh2-*.tar*
cd libssh2-*

if [[ "${_libssh2_ver}" == '1.11.0' ]]; then
    echo 'diff --git a/configure.ac b/configure.ac
    index a4d386b..6b79684 100644
    --- a/configure.ac
    +++ b/configure.ac
    @@ -387,6 +387,8 @@ elif test "$found_crypto" = "mbedtls"; then
       LIBS="${LIBS} ${LTLIBMBEDCRYPTO}"
     fi
 
    +LIBS="${LIBS} ${LTLIBZ}"
    +
     AC_CONFIG_FILES([Makefile
                      src/Makefile
                      tests/Makefile
    diff --git a/src/Makefile.am b/src/Makefile.am
    index 91222d5..380674b 100644
    --- a/src/Makefile.am
    +++ b/src/Makefile.am
    @@ -48,8 +48,7 @@ VERSION=-version-info 1:1:0
     #
 
     libssh2_la_LDFLAGS = $(VERSION) -no-undefined \
    -  -export-symbols-regex '\''^libssh2_.*'\'' \
    -  $(LTLIBZ)
    +  -export-symbols-regex '\''^libssh2_.*'\''
 
     if HAVE_WINDRES
     .rc.lo:' > ../fix-build-with-openssl111.patch
    sed 's|^    ||g' -i ../fix-build-with-openssl111.patch
    patch -N -p1 -i ../fix-build-with-openssl111.patch
    autoreconf -ifv
    rm -fr autom4te.cache
    rm -f configure.ac.orig src/Makefile.am.orig
fi

./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--prefix=/usr \
--libdir=/usr/lib64 \
--includedir=/usr/include \
--sysconfdir=/etc \
--enable-shared --enable-static \
--disable-silent-rules \
--with-libz \
--enable-debug \
--with-crypto=openssl \
--with-libssl-prefix=/usr/local/openssl-1.1.1
sleep 1
make all
sleep 1
rm -fr /tmp/libssh2
sleep 1
make install DESTDIR=/tmp/libssh2
sleep 1
cd /tmp/libssh2/
_strip_and_zipman

echo
sleep 2
tar -Jcvf /tmp/libssh2-"${_libssh2_ver}"-1.el7.x86_64.tar.xz *
echo
sleep 2

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/libssh2
printf '\033[01;32m%s\033[m\n' '  build libssh2 done'
echo
exit


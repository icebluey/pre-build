#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
/sbin/ldconfig >/dev/null 2>&1

#yum makecache
#yum install -y m4 libtool
#yum install -y libtasn1-devel libffi-devel nss-softokn-freebl libunistring-devel
## build gnutls for chrony
#yum install -y p11-kit-devel
## build chrony
#yum install -y libseccomp-devel libcap-devel postfix

#yum install -y libedit-devel

umask 022

CFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CFLAGS
CXXFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CXXFLAGS
LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -specs=/usr/lib/rpm/redhat/redhat-hardened-ld'
export LDFLAGS

_ORIG_LDFLAGS="$LDFLAGS"
LDFLAGS="${_ORIG_LDFLAGS} -Wl,-rpath,/usr/lib64/chrony/private"
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
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs -r -I '{}' chmod 0755 '{}'
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

if ! grep -q -i '^1:.*docker' /proc/1/cgroup; then
    echo
    echo ' Not in a container!'
    echo
    exit 1
fi

############################################################################
############################################################################
############################################################################

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_p11_kit_ver="$(wget -qO- 'https://github.com/p11-glue/p11-kit/releases' | grep -i 'href="/p11-glue/p11-kit/releases/download/.*tar.*' | sed 's|"|\n|g' | grep -i '^/p11-glue/p11-kit/releases/download/' | grep -ivE 'alpha|beta|rc' | sed -e 's|.*download/||g' -e 's|/p.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 0 -T 9 "https://github.com/p11-glue/p11-kit/releases/download/${_p11_kit_ver}/p11-kit-${_p11_kit_ver}.tar.xz"
sleep 1
tar -xf "p11-kit-${_p11_kit_ver}.tar.xz"
sleep 1
rm -f "p11-kit-${_p11_kit_ver}.tar.xz"
cd "p11-kit-${_p11_kit_ver}"

./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--prefix=/usr \
--exec-prefix=/usr \
--sysconfdir=/etc \
--datadir=/usr/share \
--includedir=/usr/include \
--libdir=/usr/lib64 \
--libexecdir=/usr/libexec \
--disable-static \
--disable-doc \
--with-trust-paths=/etc/pki/ca-trust/source:/usr/share/pki/ca-trust-source \
--with-hash-impl=freebl --disable-silent-rules
sleep 1
make all
sleep 1
make install DESTDIR=/tmp/p11-kit
cd /tmp/p11-kit
rm -fr usr/share/gtk-doc
_strip_and_zipman
sleep 1
install -m 0755 -d usr/lib64/chrony/private
sleep 1
cp -a usr/lib64/*.so* usr/lib64/chrony/private/
echo
sleep 2
tar -Jcvf /tmp/"p11-kit-${_p11_kit_ver}-1.el7.x86_64.tar.xz" *
echo
sleep 2
tar -xf /tmp/"p11-kit-${_p11_kit_ver}-1.el7.x86_64.tar.xz" -C /
cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/p11-kit
rm -f /tmp/p11-kit*.tar*
printf '\033[01;32m%s\033[m\n' '  build p11-kit done'
/sbin/ldconfig
echo

############################################################################
############################################################################
############################################################################

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_libidn2_ver=$(wget -qO- 'https://ftp.gnu.org/gnu/libidn/' | grep -i 'a href="libidn2.*\.tar' | sed 's/"/\n/g' | grep -i '^libidn2-.*tar.gz$' | sed -e 's|libidn2-||g' -e 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc|latest' | sort -V | uniq | tail -n 1)
wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/libidn/libidn2-${_libidn2_ver}.tar.gz"
sleep 1
tar -xf "libidn2-${_libidn2_ver}.tar.gz"
sleep 1
rm -f "libidn2-${_libidn2_ver}.tar.gz"
cd "libidn2-${_libidn2_ver}"

./configure \
--build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--prefix=/usr --exec-prefix=/usr --sysconfdir=/etc \
--datadir=/usr/share --includedir=/usr/include \
--libdir=/usr/lib64 --libexecdir=/usr/libexec \
--disable-static --disable-doc 
sleep 1
make all
rm -fr /tmp/libidn2
make install DESTDIR=/tmp/libidn2

cd /tmp/libidn2
sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
_strip_and_zipman
sleep 1
install -m 0755 -d usr/lib64/chrony/private
sleep 1
cp -a usr/lib64/*.so* usr/lib64/chrony/private/

echo
sleep 2
tar -Jcvf /tmp/"libidn2-${_libidn2_ver}-1.el7.x86_64.tar.xz" *
echo
sleep 2
tar -xf /tmp/"libidn2-${_libidn2_ver}-1.el7.x86_64.tar.xz" -C /

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/libidn2
rm -f /tmp/libidn2*.tar*
printf '\033[01;32m%s\033[m\n' '  build libidn2 done'
/sbin/ldconfig
echo

############################################################################
############################################################################
############################################################################

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_nettle_ver=$(wget -qO- 'https://ftp.gnu.org/gnu/nettle/' | grep -i 'a href="nettle.*\.tar' | sed 's/"/\n/g' | grep -i '^nettle-.*tar.gz$' | sed -e 's|nettle-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)
wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/nettle/nettle-${_nettle_ver}.tar.gz"
sleep 1
tar -xf "nettle-${_nettle_ver}.tar.gz"
sleep 1
rm -f "nettle-${_nettle_ver}.tar.gz"
cd "nettle-${_nettle_ver}"

./configure \
--build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--prefix=/usr --libdir=/usr/lib64 \
--includedir=/usr/include --sysconfdir=/etc \
--enable-shared --enable-static --enable-fat \
--disable-openssl
sleep 1
make all
rm -fr /tmp/nettle
make install DESTDIR=/tmp/nettle

cd /tmp/nettle
sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
_strip_and_zipman
sleep 1
install -m 0755 -d usr/lib64/chrony/private
sleep 1
cp -a usr/lib64/*.so* usr/lib64/chrony/private/

echo
sleep 2
tar -Jcvf /tmp/"nettle-${_nettle_ver}-1.el7.x86_64.tar.xz" *
echo
sleep 2
tar -xf /tmp/"nettle-${_nettle_ver}-1.el7.x86_64.tar.xz" -C /

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/nettle
rm -f /tmp/nettle*.tar*
printf '\033[01;32m%s\033[m\n' '  build nettle done'
/sbin/ldconfig
echo

############################################################################
############################################################################
############################################################################

bash /opt/gcc/set-static-libstdcxx

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_gnutls_ver="$(wget -qO- 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/' | grep -i 'a href="gnutls.*\.tar' | sed 's/"/\n/g' | grep -i '^gnutls-.*tar.xz$' | sed -e 's|gnutls-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 0 -T 9 "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-${_gnutls_ver}.tar.xz"
sleep 1
tar -xf "gnutls-${_gnutls_ver}.tar.xz"
sleep 1
rm -f "gnutls-${_gnutls_ver}.tar.xz"
cd "gnutls-${_gnutls_ver}"

./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--enable-shared \
--enable-threads=posix \
--enable-sha1-support \
--enable-ssl3-support \
--enable-fips140-mode \
--disable-openssl-compatibility \
--with-included-unistring \
--with-included-libtasn1 \
--prefix=/usr \
--libdir=/usr/lib64 \
--includedir=/usr/include \
--sysconfdir=/etc
sleep 1
make all
rm -fr /tmp/gnutls
make install DESTDIR=/tmp/gnutls
cd /tmp/gnutls
sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
_strip_and_zipman
sleep 1
install -m 0755 -d usr/lib64/chrony/private
sleep 1
cp -a usr/lib64/*.so* usr/lib64/chrony/private/
echo
sleep 2
tar -Jcvf /tmp/"gnutls-${_gnutls_ver}-1.el7.x86_64.tar.xz" *
echo
sleep 2
tar -xf /tmp/"gnutls-${_gnutls_ver}-1.el7.x86_64.tar.xz" -C /
cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/gnutls
rm -f /tmp/gnutls*.tar*
printf '\033[01;32m%s\033[m\n' '  build gnutls done'
/sbin/ldconfig
echo

bash /opt/gcc/set-shared-libstdcxx

############################################################################
############################################################################
############################################################################

/sbin/ldconfig

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

#https://download.tuxfamily.org/chrony/chrony-4.2.tar.gz
_chrony_ver="$(wget -qO- 'https://chrony.tuxfamily.org/download.html' | grep 'chrony-[1-9].*\.tar' | sed 's|"|\n|g' | sed 's|chrony|\nchrony|g' | grep '^chrony-[1-9]' | sed -e 's|\.tar.*||g' -e 's|chrony-||g' | sort -V | uniq | tail -n 1)"
wget -c -t 9 -T 9 "https://download.tuxfamily.org/chrony/chrony-${_chrony_ver}.tar.gz"
sleep 1
tar -xf chrony-${_chrony_ver}.tar.*
sleep 1
rm -f chrony-*.tar*
cd chrony-*

./configure \
--prefix=/usr \
--mandir=/usr/share/man \
--sysconfdir=/etc/chrony \
--chronyrundir=/run/chrony \
--docdir=/usr/share/doc \
--enable-scfilter \
--enable-ntp-signd \
--enable-debug \
--with-ntp-era=$(date -d '1970-01-01 00:00:00+00:00' +'%s') \
--with-hwclockfile=/etc/adjtime \
--with-pidfile=/run/chrony/chronyd.pid \
--with-sendmail=/usr/sbin/sendmail
sleep 1
make all
sleep 1
rm -fr /tmp/chrony
sleep 1
make install DESTDIR=/tmp/chrony
sleep 1
install -m 0755 -d /tmp/chrony/etc/chrony
install -m 0755 -d /tmp/chrony/etc/sysconfig
install -m 0755 -d /tmp/chrony/etc/dhcp/dhclient.d
install -m 0755 -d /tmp/chrony/etc/logrotate.d
cd examples
install -v -c -m 0644 chrony.conf.example2 /tmp/chrony/etc/chrony/chrony.conf
install -v -c -m 0640 chrony.keys.example /tmp/chrony/etc/chrony/chrony.keys
install -v -c -m 0644 chrony.logrotate /tmp/chrony/etc/logrotate.d/chrony
install -v -c -m 0644 chrony-wait.service /tmp/chrony/etc/chrony/chrony-wait.service
install -v -c -m 0644 chronyd.service /tmp/chrony/etc/chrony/chronyd.service

cd /tmp/chrony/
rm -fr var/run
install -m 0755 -d usr/lib64/chrony
install -m 0755 -d usr/lib/NetworkManager/dispatcher.d
install -m 0755 -d usr/lib/systemd/ntp-units.d
_strip_and_zipman
cp -a /usr/lib64/chrony/private usr/lib64/chrony/

_systemd_env_list=''
_systemd_env_list=(
LockPersonality
MemoryDenyWriteExecute
ProcSubset
ProtectControlGroups
ProtectHostname
ProtectKernelLogs
ProtectKernelModules
ProtectKernelTunables
ProtectProc
ReadWritePaths
RestrictNamespaces
RestrictSUIDSGID
)
for i in ${_systemd_env_list[@]}; do sed "s|^${i}=|#${i}=|g" -i etc/chrony/chronyd.service ; done
for i in ${_systemd_env_list[@]}; do sed "s|^${i}=|#${i}=|g" -i etc/chrony/chrony-wait.service ; done
sed 's|ProtectSystem=.*|ProtectSystem=full|g' -i etc/chrony/chronyd.service
sed 's|ProtectSystem=.*|ProtectSystem=full|g' -i etc/chrony/chrony-wait.service
_systemd_env_list=''

sed -e 's|#\(driftfile\)|\1|' \
-e 's|#\(rtcsync\)|\1|' \
-e 's|#\(keyfile\)|\1|' \
-e 's|#\(leapsectz\)|\1|' \
-e 's|#\(logdir\)|\1|' \
-e 's|#\(authselectmode\)|\1|' \
-e 's|#\(ntsdumpdir\)|\1|' \
-i etc/chrony/chrony.conf
sed 's|/etc/chrony\.|/etc/chrony/chrony\.|g' -i etc/chrony/chrony.conf
sed 's/^pool /#pool /g' -i etc/chrony/chrony.conf
sed 's/^allow /#allow /g' -i etc/chrony/chrony.conf
sed 's/^server/#server/g' -i etc/chrony/chrony.conf
sed '3a\\nserver time.cloudflare.com iburst nts\n#server nts.ntp.se iburst nts\nserver nts.sth1.ntp.se iburst nts\nserver nts.sth2.ntp.se iburst nts\n#server time1.google.com iburst\n#server time2.google.com iburst\n#server time3.google.com iburst\n#server time4.google.com iburst' -i etc/chrony/chrony.conf
sed '/^After=/aAfter=dnscrypt-proxy.service network-online.target' -i etc/chrony/chronyd.service
#sed '/^ExecStart=/iExecStartPre=/usr/libexec/chrony/resolve-ntp-servers.sh' -i etc/chrony/chronyd.service

echo '# Command-line options for chronyd
OPTIONS="-F 2"' > etc/sysconfig/chronyd
sleep 1
chmod 0644 etc/sysconfig/chronyd
echo '
/var/log/chrony/*.log {
    missingok
    nocreate
    sharedscripts
    postrotate
        /usr/bin/chronyc cyclelogs > /dev/null 2>&1 || true
    endscript
}' > etc/logrotate.d/chrony
sleep 1
chmod 0644 etc/logrotate.d/chrony

echo '#!/usr/bin/bash

CHRONY_SOURCEDIR=/run/chrony-dhcp
SERVERFILE=$CHRONY_SOURCEDIR/$interface.sources

chrony_config() {
    # Disable modifications if called from a NM dispatcher script
    [ -n "$NM_DISPATCHER_ACTION" ] && return 0

    rm -f "$SERVERFILE"
    if [ "$PEERNTP" != "no" ]; then
        mkdir -p $CHRONY_SOURCEDIR
        for server in $new_ntp_servers; do
            echo "server $server ${NTPSERVERARGS:-iburst}" >> "$SERVERFILE"
        done
        /usr/bin/chronyc reload sources > /dev/null 2>&1 || :
    fi
}

chrony_restore() {
    [ -n "$NM_DISPATCHER_ACTION" ] && return 0

    if [ -f "$SERVERFILE" ]; then
        rm -f "$SERVERFILE"
        /usr/bin/chronyc reload sources > /dev/null 2>&1 || :
    fi
}' > etc/dhcp/dhclient.d/chrony.sh
sleep 1
chmod 0755 etc/dhcp/dhclient.d/chrony.sh

echo '#!/usr/bin/sh
# This is a NetworkManager dispatcher script for chronyd to update
# its NTP sources passed from DHCP options. Note that this script is
# specific to NetworkManager-dispatcher due to use of the
# DHCP4_NTP_SERVERS environment variable.

export LC_ALL=C

interface=$1
action=$2

chronyc=/usr/bin/chronyc
default_server_options=iburst
server_dir=/run/chrony-dhcp

dhcp_server_file=$server_dir/$interface.sources
# DHCP4_NTP_SERVERS is passed from DHCP options by NetworkManager.
nm_dhcp_servers=$DHCP4_NTP_SERVERS

[ -f /etc/sysconfig/network ] && . /etc/sysconfig/network
[ -f /etc/sysconfig/network-scripts/ifcfg-"${interface}" ] && \
    . /etc/sysconfig/network-scripts/ifcfg-"${interface}"

add_servers_from_dhcp() {
    rm -f "$dhcp_server_file"

    # Don'\''t add NTP servers if PEERNTP=no specified; return early.
    [ "$PEERNTP" = "no" ] && return

    for server in $nm_dhcp_servers; do
        echo "server $server ${NTPSERVERARGS:-$default_server_options}" >> "$dhcp_server_file"
    done
    $chronyc reload sources > /dev/null 2>&1 || :
}

clear_servers_from_dhcp() {
    if [ -f "$dhcp_server_file" ]; then
        rm -f "$dhcp_server_file"
        $chronyc reload sources > /dev/null 2>&1 || :
    fi
}

mkdir -p $server_dir

if [ "$action" = "up" ] || [ "$action" = "dhcp4-change" ]; then
    add_servers_from_dhcp
elif [ "$action" = "down" ]; then
    clear_servers_from_dhcp
fi

exit 0' > usr/lib/NetworkManager/dispatcher.d/20-chrony-dhcp
sleep 1
chmod 0755 usr/lib/NetworkManager/dispatcher.d/20-chrony-dhcp

echo '#!/usr/bin/sh
# This is a NetworkManager dispatcher / networkd-dispatcher script for
# chronyd to set its NTP sources online or offline when a network interface
# is configured or removed

export LC_ALL=C

chronyc=/usr/bin/chronyc

# For NetworkManager consider only up/down events
[ $# -ge 2 ] && [ "$2" != "up" ] && [ "$2" != "down" ] && exit 0

# Note: for networkd-dispatcher routable.d ~= on and off.d ~= off

$chronyc onoffline > /dev/null 2>&1

exit 0' > usr/lib/NetworkManager/dispatcher.d/20-chrony-onoffline
sleep 1
chmod 0755 usr/lib/NetworkManager/dispatcher.d/20-chrony-onoffline

echo 'chronyd.service' > usr/lib/systemd/ntp-units.d/50-chronyd.list
echo 'chronyd.service' > usr/lib/systemd/ntp-units.d/50-chrony.list
sleep 1
chmod 0644 usr/lib/systemd/ntp-units.d/50-chrony*list

echo '
cd "$(dirname "$0")"
/bin/systemctl stop chronyd >/dev/null 2>&1 || : 
/bin/systemctl stop chrony >/dev/null 2>&1 || : 
/bin/systemctl disable chronyd >/dev/null 2>&1 || : 
/bin/systemctl disable chrony >/dev/null 2>&1 || : 
rm -fr /lib/systemd/system/chrony.service
rm -fr /lib/systemd/system/chronyd.service
rm -fr /lib/systemd/system/chrony-wait.service
rm -fr /run/chrony
rm -f /etc/init.d/chrony
rm -fr /var/lib/chrony/*
/bin/systemctl daemon-reload >/dev/null 2>&1 || : 
sleep 1
install -v -c -m 0644 chronyd.service /lib/systemd/system/
install -v -c -m 0644 chrony-wait.service /lib/systemd/system/
ln -svf chronyd.service /lib/systemd/system/chrony.service
install -m 0755 -d /var/log/chrony
install -m 0755 -d /var/lib/chrony
touch /var/lib/chrony/{drift,rtc}
/bin/systemctl daemon-reload >/dev/null 2>&1 || : 
' > etc/chrony/.install.txt

echo
sleep 2
tar -Jcvf /tmp/chrony-"${_chrony_ver}"-1.el7.x86_64.tar.xz *
echo
sleep 2

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/chrony
printf '\033[01;32m%s\033[m\n' '  build chrony done'
echo
exit


#!/bin/sh
#
# Copyright (c) 2013 Citrix Systems, Inc.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

export PATH="/sbin:/usr/sbin:$PATH"

mount -t devtmpfs none /dev

#exec 0<&-                      
#exec 1<&-              
#exec 2<&-

exec 0< /dev/hvc0
exec 1> /dev/hvc0
exec 2> /dev/hvc0


## the modprobe of busybox-static is broken
## so we have to use insmod directly
insmod /lib/modules/`uname -r`/extra/v4v.ko

sync
mkdir -p /proc /sys /mnt /tmp
mount -t proc proc /proc
mount -t xenfs none /proc/xen
mount -t sysfs sysfs /sys

lsmod

echo "0" > /sys/bus/pci/drivers_autoprobe
for pci_dev in `ls /sys/bus/pci/devices/`
do
 if [ -e /sys/bus/pci/devices/$pci_dev/driver/unbind ]
 then
    echo pci device $pci_dev is bound, unbounding it!
    echo "$pci_dev" > /sys/bus/pci/devices/$pci_dev/driver/unbind
 fi
done

echo "Command line: `cat /proc/cmdline`"

ln -s /proc/self/fd/2 /dev/stderr

QEMU_CMDLINE=`cat /proc/cmdline | cut -d' ' -f4- `

DOMID=`echo $QEMU_CMDLINE | cut -d' ' -f2 `

echo $*
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

# Probably not the most elegant way to do that.
/etc/qemu/qemu-ifup setup "brbridged" "eth0"
/etc/qemu/qemu-ifup setup "brwireless" "eth1"

mkdir -p /var/run
export USE_INTEL_SB=1
export INTEL_DBUS=1

rsyslogd -f /etc/rsyslog.conf -c4

is_dmagent=`echo $QEMU_CMDLINE | cut -d' ' -f1`

if [ "$is_dmagent" == "dmagent" ]; then
    echo "start dm-agent"
    exec /usr/bin/dm-agent -q -n -t $DOMID &
else
    echo "-stubdom -name qemu-$DOMID $QEMU_CMDLINE"
    exec /usr/bin/qemu-dm-wrapper $DOMID -stubdom -name qemu-$DOMID $QEMU_CMDLINE
fi

/sbin/getty 115200 hvc0 -n -l /bin/sh

while pidof qemu-system-i386 > /dev/null ; do
    echo "Shutdown aborted, as QEMU wouldn't have time to clean up." > /dev/hvc0
    echo > /dev/hvc0
    echo "pkill -TERM qemu-system-i386 first!" > /dev/hvc0
    echo > /dev/hvc0
    /sbin/getty 115200 hvc0 -n -l /bin/sh
done

#... finally, shut down the stubdom properly. This avoids a scary-looking kernel panic.
shutdown -f


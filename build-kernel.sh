#!/bin/sh
# Configure + build Linux 6.8.12 (i386) with the CodePaws rootfs embedded.
# Run from ~/workspace/v86-image-build/ after rootfs/ is populated.
set -e
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
KSRC="$BUILD_DIR/src/linux-6.8.12"
cd "$KSRC"

make ARCH=i386 allnoconfig

CFG="scripts/config --file .config"
# --- core ---
$CFG -e EXPERT -e EMBEDDED -e PRINTK -e TTY -e BINFMT_ELF -e BINFMT_SCRIPT
$CFG -e BLK_DEV_INITRD --set-str INITRAMFS_SOURCE "$BUILD_DIR/rootfs $BUILD_DIR/devnodes.list"
$CFG -e RD_GZIP
$CFG -e INITRAMFS_COMPRESSION_GZIP
# embedded initramfs built by the kernel: force gzip choice (INITRAMFS_COMPRESSION choice)
$CFG -e DEVTMPFS -e PROC_FS -e SYSFS -e TMPFS
$CFG -e SERIAL_8250 -e SERIAL_8250_CONSOLE
$CFG -e VGA_CONSOLE -e DUMMY_CONSOLE
$CFG -e CC_OPTIMIZE_FOR_PERFORMANCE
$CFG -d CC_OPTIMIZE_FOR_SIZE
$CFG -e M686
$CFG -d M486 -d M586 -d M586TSC -d M586MMX -d MPENTIUMII -d MPENTIUMIII -d MPENTIUMM -d MPENTIUM4 -d MCORE2 -d MATOM -d GENERIC_CPU
# make sure the CPU choice sticks: exactly one of the X86 cpu selection bools
# (olddefconfig resolves the choice; M686 is in the Pentium-II/Celeron group)
$CFG -e EARLY_PRINTK
# --- explicitly off (allnoconfig mostly handles these; belt & braces) ---
$CFG -d MODULES -d SMP -d NET -d PCI -d ACPI -d PM -d SOUND -d USB_SUPPORT \
     -d INPUT -d SERIO -d HID -d BLOCK -d SCSI -d ATA -d MD -d WIRELESS -d WLAN \
     -d ETHERNET -d IPV6 -d XFRM -d INET -d BT -d NFC -d MEDIA_SUPPORT -d DRM \
     -d FB -d LOGO -d CONSOLE_LOGLEVEL_QUIET
$CFG -d LOGO_LINUX_MONO -d LOGO_LINUX_VGA16 -d LOGO_LINUX_CLUT224
# keep only the filesystems we use
$CFG -d EXT2_FS -d EXT3_FS -d EXT4_FS -d XFS_FS -d BTRFS_FS -d VFAT_FS -d NTFS_FS \
     -d ISO9660_FS -d NFS_FS -d AUTOFS_FS -d FUSE_FS -d OVERLAY_FS -d SQUASHFS
$CFG -e SHMEM -e RAMFS

make ARCH=i386 olddefconfig
cp .config ../../kernel.config

# sanity greps (fail loudly if a must-have got dropped by olddefconfig)
for sym in CONFIG_SERIAL_8250_CONSOLE CONFIG_BLK_DEV_INITRD CONFIG_TTY CONFIG_PRINTK CONFIG_DEVTMPFS CONFIG_PROC_FS CONFIG_TMPFS CONFIG_BINFMT_ELF; do
  grep -q "^${sym}=y" .config || { echo "MISSING $sym"; exit 1; }
done
grep -q "CONFIG_INITRAMFS_SOURCE=\"$BUILD_DIR/rootfs $BUILD_DIR/devnodes.list\"" .config || { echo "INITRAMFS_SOURCE wrong"; grep INITRAMFS_SOURCE .config; exit 1; }

make ARCH=i386 -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage ../../codepaws-bzimage.bin
ls -la ../../codepaws-bzimage.bin

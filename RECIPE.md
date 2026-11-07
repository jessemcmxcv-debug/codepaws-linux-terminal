# CodePaws v86 Linux Image — Build Recipe

A purpose-built, minimal, self-contained Linux bzImage for the v86 browser
emulator (CodePaws Academy "real Linux" revival). One file: kernel + embedded
initramfs. Boots to an interactive BusyBox shell on the serial console.

**Output:** `codepaws-bzimage.bin` — 2,318,848 bytes (gzip −9: 2,299,966 bytes).

This document is also the GPL source-offer record: both non-trivial components
(Linux kernel, BusyBox) are GPL-2.0, built from the unmodified upstream sources
below with the configuration files kept in this directory (`kernel.config`,
`busybox.config`). No patches were applied to either source tree.

---

## Fixed contract the image is built for

- Emulator: v86 0.5.473 (`libv86.js` + `v86.wasm`), SeaBIOS + VGABIOS from the
  v86 repo.
- Emulator settings: `memory_size` 32 MiB, `vga_memory_size` 2 MiB,
  cmdline exactly `console=ttyS0 clocksource=pit tsc=unstable`,
  `autostart: true`. (The clock terms were added 2026-11-05, after the
  owner's phone test: the emulated TSC drifts, so the kernel's
  clocksource watchdog used to mark TSC unstable and switch to PIT
  AFTER the shell was up, printing a block of clocksource lines into
  the console. Choosing PIT from the start and marking TSC unstable
  via the boot parameter makes both events happen silently during
  boot instead; verified in the boot log — see
  `snapshot-results.json`, `clock_lines_in_serial_at_save`. The
  bzImage itself is unchanged by this: the cmdline is supplied by
  the emulator, not compiled in.)
- The image is ONE bzImage with the initramfs embedded
  (`CONFIG_INITRAMFS_SOURCE`); no separate initrd.
- Readiness contract: `/init` prints the exact line `CODEPAWS_SHELL_READY`
  to the console immediately before handing over to the interactive shell.
- Prompt: BusyBox ash with `PS1='\u@\h:\w\$ '` → renders as
  `root@codepaws:~# ` in `$HOME`, `root@codepaws:/tmp# ` after `cd /tmp`
  (verified empirically in the guest; ash substitutes `~` for `$HOME`).

## Sources (exact)

| Component | Version | URL |
|---|---|---|
| Linux kernel | 6.8.12 | https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.12.tar.xz |
| BusyBox | 1.36.1 | https://busybox.net/downloads/busybox-1.36.1.tar.bz2 |

Downloaded tarballs and extracted trees are kept under `src/` in this
directory (`src/linux-6.8.12/`, `src/busybox-1.36.1/`).

## Host build dependencies

Ubuntu 24.04 packages:

```
bc flex bison cpio xz-utils libelf-dev libc6-dev-i386 gcc-multilib
```

Notes from the original build host:
- `apt-get update` hung on the dead `mirror.cogentco.com` mirror; the azure
  mirror worked. `-o Acquire::ForceIPv4=true` was used.
- The build sandbox forbids `mknod` ("Operation not permitted") even as root —
  that is why the fallback device nodes are supplied via a `gen_init_cpio`
  list file (`devnodes.list`) instead of existing on disk in `rootfs/dev/`
  (see below). On an unrestricted host, real nodes in the rootfs would also
  work; the list-file approach works everywhere.
- The build host's kernel cannot execute i386 binaries at all (they segfault
  on the host); all guest testing was done inside v86 itself, which is the
  only test that matters.

## Build steps (exact)

Everything below is scripted in this directory: `build-busybox.sh`,
`populate-rootfs.sh`, `build-kernel.sh`. Run in that order.

```sh
# 0. fetch + extract
mkdir -p src
curl -fsSL -o src/linux-6.8.12.tar.xz  https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.12.tar.xz
curl -fsSL -o src/busybox-1.36.1.tar.bz2 https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar -C src -xf src/linux-6.8.12.tar.xz
tar -C src -xf src/busybox-1.36.1.tar.bz2

# 1. BusyBox (static, i386, trimmed) → installs into rootfs/
./build-busybox.sh

# 2. seed files, /init, /etc/profile into rootfs/
./populate-rootfs.sh

# 3. kernel (i386) with rootfs/ + devnodes.list embedded → codepaws-bzimage.bin
./build-kernel.sh
```

Rebuilding after changing only rootfs content (e.g. `/init`): re-copy the file
into `rootfs/` and re-run step 3 — the kernel build regenerates the embedded
initramfs and relinks (~15 s).

## BusyBox configuration

Approach: `make allnoconfig`, then enable exactly the set below with sed on
`.config`, settle with `yes "" | make oldconfig`, build with
`make CC="gcc -m32" HOSTCC=gcc`, install with
`make CONFIG_PREFIX=<rootfs> CC="gcc -m32" HOSTCC=gcc install`.
Full final config: **`busybox.config`** in this directory.
Result: static ELF i386 binary, 1,545,244 bytes, 92 applet links.

Enabled (beyond allnoconfig defaults):

- Core: `STATIC`, `LONG_OPTS`, `PLATFORM_LINUX`, `FEATURE_HUMAN_READABLE`
- Shell: `ASH` + `FEATURE_SH_IS_ASH`, `ASH_JOB_CONTROL`, `ASH_ALIAS`,
  `ASH_GETOPTS`, `ASH_BUILTIN_ECHO`, `ASH_BUILTIN_PRINTF`, `ASH_BUILTIN_TEST`,
  **`ASH_EXPAND_PRMT`** (required for `\u \h \w` in PS1), `ASH_RANDOM_SUPPORT`,
  `ASH_SLEEP`; line editing: `FEATURE_EDITING`, `FEATURE_TAB_COMPLETION`,
  `FEATURE_EDITING_FANCY_PROMPT`, `FEATURE_EDITING_SAVEHISTORY`
- Applets: ash/sh, cat, chgrp, chmod, chown, cp, cut, date, dd, df, dirname,
  dmesg, du, echo, env, printenv, expr, false, find, free, grep (+egrep/fgrep),
  head, hostname, id, kill, killall, less, ln, ls, mkdir, mkfifo, mknod,
  more, mount, mv, pgrep, pidof, pkill, printf, ps, pwd, readlink, realpath,
  rm, rmdir, sed, seq, setsid, sleep, sort, stat, stty, sync, tail, tar,
  tee, test (+`[`, `[[`), timeout, top, touch, tr, true, tty, umount, uname,
  uniq, uptime, vi, wc, which, whoami, xargs, yes, awk, basename, clear, cmp,
  md5sum, sha256sum, hexdump, diff, getopt, mktemp, cttyhack,
  gzip, gunzip, zcat
- Feature flags: LS filetypes/recursive/sort/timestamps/username, grep
  context + egrep/fgrep aliases, a broad `find` feature set (type, perm,
  newer, exec, prune, delete, regex, …), vi colon/yankmark/search/dot-cmd/
  readonly/setopts, less brackets/flags/regexp/winch, tar create, top CPU %.

Deliberately NOT built: every networking applet and daemon (no kernel NET),
init/getty/login (PID 1 is a shell script), syslogd/crond/mdev/module tools,
package managers, filesystem/block-device tools, editors other than vi.

## Kernel configuration

Approach: `make ARCH=i386 allnoconfig`, then `scripts/config` deltas,
`make ARCH=i386 olddefconfig`. Full final config: **`kernel.config`** in this
directory (the delta below is the meaningful part).

Enabled:

```
EXPERT EMBEDDED PRINTK TTY BINFMT_ELF BINFMT_SCRIPT
BLK_DEV_INITRD  INITRAMFS_SOURCE="<builddir>/rootfs <builddir>/devnodes.list"
RD_GZIP INITRAMFS_COMPRESSION_GZIP
DEVTMPFS PROC_FS SYSFS TMPFS SHMEM RAMFS
SERIAL_8250 SERIAL_8250_CONSOLE VGA_CONSOLE DUMMY_CONSOLE EARLY_PRINTK
CC_OPTIMIZE_FOR_PERFORMANCE (not _FOR_SIZE — emulation speed beats bytes)
M686 (Pentium-II/Celeron/Pentium-III-class CPU choice)
```

Explicitly disabled (most are allnoconfig defaults anyway):
`MODULES SMP NET PCI ACPI PM SOUND USB_SUPPORT INPUT SERIO HID BLOCK SCSI
ATA MD WIRELESS WLAN ETHERNET IPV6 BT NFC MEDIA DRM FB LOGO` and all
filesystems except ramfs/tmpfs/proc/sysfs/devtmpfs (no ext*, xfs, btrfs,
vfat, ntfs, iso9660, nfs, fuse, overlay, squashfs).

Consequences worth knowing:
- `BLOCK` is off entirely: no block devices at all; the rootfs is the
  initramfs and `/tmp` is tmpfs. Nothing to mount, nothing to wait for.
- No `INPUT`/keyboard drivers: the serial console (ttyS0) is the only
  interactive channel; VGA console is compiled in so the emulated screen
  shows the same boot log, but there is no keyboard input path.
- `usr/initramfs_data.cpio` in the build tree is the embedded archive
  (1,562,112 B uncompressed); the whole vmlinux is then gzip-compressed by
  the bzImage compressor as usual.

## Rootfs layout

Produced by BusyBox `make install` into `rootfs/`, plus `populate-rootfs.sh`:

```
rootfs/
├── init                # PID 1 shell script (below), mode 755
├── bin/, usr/bin/      # busybox binary + applet symlinks
├── etc/
│   ├── profile         # PS1 + cd $HOME (below)
│   ├── passwd          # root:x:0:0:root:/root:/bin/sh
│   ├── group           # root:x:0:
│   ├── hostname        # "codepaws"
│   └── motd
├── root/
│   ├── README.txt      # 3-line welcome
│   └── practice/notes.txt   # 4 lines of practice text
├── dev/ proc/ sys/     # mount points (devtmpfs/proc/sysfs mounted by /init)
├── tmp/                # tmpfs, mode 1777
└── home/
```

Total seed content < 1 KB. Fallback static device nodes are NOT in this
directory tree; they are injected at kernel-build time from `devnodes.list`
(the second `CONFIG_INITRAMFS_SOURCE` entry):

```
dir /dev 0755 0 0
nod /dev/console 0600 0 0 c 5 1
nod /dev/ttyS0  0600 0 0 c 4 64
nod /dev/null   0666 0 0 c 1 3
```

(The kernel needs `/dev/console` in the initramfs to give PID 1 its initial
console; devtmpfs takes over once `/init` mounts it.)

### /init (exact contents; also kept as `rootfs-init` in this directory)

```sh
#!/bin/sh
# CodePaws v86 image /init — PID 1 shell script (BusyBox sh).
# Mounts the pseudo-filesystems, prints a brief welcome, signals shell
# readiness, then hands the console over to an interactive login shell.
/bin/mount -t devtmpfs devtmpfs /dev
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t tmpfs tmpfs /tmp
/bin/hostname codepaws
export HOME=/root
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
echo "Welcome to CodePaws Linux - a REAL Linux kernel running in your browser."
echo "Try: uname -a   ls   cat /root/README.txt"
echo "Heads up: files vanish when the page reloads."
echo "CODEPAWS_SHELL_READY"
exec setsid -c sh -l
```

Two hard-won details:
- `setsid` must be found via PATH (BusyBox installs it in `/usr/bin`, not
  `/bin`). An absolute `/bin/setsid` path made PID 1 exit 127 →
  "Attempted to kill init" kernel panic.
- `setsid -c` gives the shell a controlling tty on the console, so job
  control and Ctrl-C work; the shell is a login shell (`-l`) so
  `/etc/profile` runs.

### /etc/profile (also kept as `rootfs-profile`)

```sh
# /etc/profile for the CodePaws v86 image — sourced by the login shell.
export HOME=/root
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PS1='\u@\h:\w\$ '
cd "$HOME"
```

## Measurement (2026-11-05, this build host)

Harness: `harness/run-measure.mjs` + `harness/index.html` in this directory —
a copy of the spike's approach (chrome-headless-shell 156.0.8078.80 +
puppeteer-core, vendored v86 0.5.473, SeaBIOS/VGABIOS from the spike dir),
with the contract settings (32 MiB RAM, 2 MiB VGA, `console=ttyS0`).
Raw results: `harness/measure-results.json`. Timings are in-page clocks
(emulator construction ≈ page load), host = the same VM as the spike report
(AMD EPYC, 4 shared vCPUs) — treat as this-VM numbers, not phone numbers.

| Run | First serial byte | CODEPAWS_SHELL_READY | Shell prompt | JS heap after boot |
|---|---|---|---|---|
| 1 | 1,465 ms | 5,383 ms | 5,566 ms | 14.5 MB |
| 2 | 1,105 ms | 4,308 ms | 4,495 ms | 13.7 MB |
| 3 | 1,344 ms | 5,245 ms | 5,357 ms | 14.5 MB |
| **median** | **1,344 ms** | **5,245 ms** | **5,357 ms** | **≈14.5 MB** |

Command battery on boot #1 — all pass: `uname -a` → `Linux codepaws 6.8.12
… i686`; `pwd` → `/root`; `cd /tmp` + prompt tracks to
`root@codepaws:/tmp#`; mkdir/echo/cat round-trip; `echo one two three |
wc -w` → `3`; `ps` shows a real process table; `free -m` total 27,760 KB
(guest-visible of the 32 MiB); seed files readable; `clear` works.
Per-command latency 77–416 ms on this host.

### Comparison with the stock spike image

| | Stock (Buildroot) image | This image |
|---|---|---|
| Kernel image bytes | 10,068,480 | **2,318,848** (23%) |
| Image gzip −9 | 10,052,445 | **2,299,966** |
| Total payload incl. emulator (raw) | 12,603,108 | **4,853,476** |
| First serial byte | ~10.8–18.3 s (userspace only) | **1.1–1.5 s** |
| Boot → shell prompt | 11–20 s (median ≈18 s) | **4.5–5.6 s (median 5.4 s)** |
| JS heap after boot | 22.0 MB (at 128 MiB guest RAM) | **≈14 MB** (at 32 MiB guest RAM) |

Unlike the stock image, kernel boot messages stream on the serial console
from ~1.3 s, so a loading UI can show real progress instead of a silent wait.

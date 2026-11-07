# CodePaws Linux Terminal — corresponding source

This repository publishes the complete corresponding source materials for the
Linux image that runs in the **Real Linux Terminal** at
[codepaws.ca](https://codepaws.ca/#/linux-terminal) — a real Linux kernel
running locally in the visitor's browser via the v86 emulator.

It exists so that the GPL source offer made on that page is a real, public
download rather than a promise. The CodePaws Academy application itself is not
part of this repository; only the terminal image's source materials are.

## What the image is

One self-contained i386 bzImage (2,318,848 bytes): a Linux kernel with an
embedded initramfs that boots straight to an interactive BusyBox shell on the
serial console. No networking, no block devices, nothing persisted — files
vanish when the page reloads, by design.

## Components and licences

Both non-trivial components are **GPL-2.0** and were built from the
**unmodified** upstream sources — no patches were applied to either tree. The
only original material is the configuration, the small seed filesystem, and
the build scripts in this repository.

| Component | Version | Licence | Upstream source |
|---|---|---|---|
| Linux kernel | 6.8.12 | GPL-2.0 (with the Linux syscall note, as upstream) | https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.12.tar.xz |
| BusyBox | 1.36.1 | GPL-2.0 | https://busybox.net/downloads/busybox-1.36.1.tar.bz2 |

The full GPL-2.0 text is in [`COPYING`](COPYING) (as shipped with BusyBox,
including its version note). The kernel's own licence note is at
`LICENSES/preferred/GPL-2.0` inside the kernel tarball above.

The v86 emulator that runs the image in the browser is a separate project
(https://github.com/copy/v86, BSD-style licence); it is not distributed from
this repository, and its notices are shown on the terminal page itself.

## What's here

| File | What it is |
|---|---|
| `RECIPE.md` | The full build record: exact sources, configuration approach, rootfs layout, boot/readiness contract, and the measurements from the original build. |
| `kernel.config` | The complete final kernel configuration (`allnoconfig` + the deltas described in the recipe). |
| `busybox.config` | The complete final BusyBox configuration. |
| `build-busybox.sh` | Builds BusyBox (static, i386) and installs it into `rootfs/`. |
| `populate-rootfs.sh` | Seeds `rootfs/` with `/init`, `/etc/profile`, and the small seed files. |
| `build-kernel.sh` | Builds the kernel with the rootfs and `devnodes.list` embedded, producing `codepaws-bzimage.bin`. |
| `rootfs-init` | `/init` — the PID 1 shell script (mounts, welcome, `CODEPAWS_SHELL_READY`, hands over to a login shell). |
| `rootfs-profile` | `/etc/profile` for the image. |
| `devnodes.list` | The `gen_init_cpio` list injecting the fallback static device nodes at build time. |

## Rebuilding

Download the two upstream tarballs (URLs above) into `src/`, extract them,
then run, in order:

```sh
./build-busybox.sh
./populate-rootfs.sh
./build-kernel.sh
```

Host dependencies and the exact contract the image is built for (emulator
settings, kernel command line, readiness signal) are documented in
[`RECIPE.md`](RECIPE.md).

## The running image

The built image and its saved-state snapshot are served from codepaws.ca
itself (the terminal page), not from this repository.

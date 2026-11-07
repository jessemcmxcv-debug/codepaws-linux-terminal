#!/bin/sh
# Populate seed files + fallback device nodes into rootfs/ (after busybox install).
set -e
cd "$(dirname "$0")/rootfs"
mkdir -p dev proc sys tmp root/practice etc home
cp ../rootfs-init init
chmod +x init
cp ../rootfs-profile etc/profile
printf 'root:x:0:0:root:/root:/bin/sh\n' > etc/passwd
printf 'root:x:0:\n' > etc/group
printf 'codepaws\n' > etc/hostname
cat > root/README.txt <<'TXT'
Welcome to CodePaws Linux!
This is a real Linux kernel running entirely in your browser tab.
Look in the practice folder and try things: ls, cd, cat, pwd.
TXT
cat > root/practice/notes.txt <<'TXT'
the quick brown fox
jumps over the lazy dog
linux is fun
practice makes perfect
TXT
printf 'CodePaws Linux - real kernel, real shell. Files vanish on reload.\n' > etc/motd
# fallback static device nodes come from ../devnodes.list at kernel build
# time (gen_init_cpio) — this sandbox forbids mknod on disk.
chmod 1777 tmp
find . | sort

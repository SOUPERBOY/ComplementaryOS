#!/bin/bash
set -e
KERNEL_RELEASE=7.1.3
ROOTFS_DIR=/home/ramos-build/rootfs
MODULES_DIR=${ROOTFS_DIR}/lib/modules/${KERNEL_RELEASE}

echo "=== Removing old modules ==="
rm -rf "${MODULES_DIR}"
mkdir -p "${MODULES_DIR}"

echo "=== Installing new modules ==="
cd /home/user/linux-7.1.3
make modules_install INSTALL_MOD_PATH="${ROOTFS_DIR}" 2>&1 | tail -5

echo "=== Running depmod ==="
chroot "${ROOTFS_DIR}" -- /sbin/depmod -a "${KERNEL_RELEASE}" 2>&1 || true

echo "=== Done ==="
du -sh "${MODULES_DIR}"
ls "${MODULES_DIR}/kernel/" 2>/dev/null | head -5

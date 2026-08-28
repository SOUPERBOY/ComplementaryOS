#!/bin/bash
set -e
KERNEL_RELEASE=7.1.3
ROOTFS_DIR=/home/ramos-build/rootfs
MODULES_DIR=${ROOTFS_DIR}/lib/modules/${KERNEL_RELEASE}

echo "=== Removing old modules ==="
rm -rf "${MODULES_DIR}"
mkdir -p "${MODULES_DIR}"

echo "=== Installing new modules (with AHCI/SATA/PATA) ==="
cd /home/user/linux-7.1.3
make modules_install INSTALL_MOD_PATH="${ROOTFS_DIR}" 2>&1 | tail -3

echo "=== Running depmod ==="
chroot "${ROOTFS_DIR}" /sbin/depmod -a "${KERNEL_RELEASE}" 2>&1 || true

echo "=== Module count ==="
find "${MODULES_DIR}/kernel" -name "*.ko" | wc -l
echo "=== AHCI/SATA/PATA modules ==="
find "${MODULES_DIR}/kernel" -name "*ahci*" -o -name "*sata*" -o -name "*pata*" 2>/dev/null | sort
du -sh "${MODULES_DIR}"
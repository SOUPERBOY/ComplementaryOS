# ComplementaryOS

A lightweight, customizable Linux distribution based on Debian, built from scratch with a custom Linux 7.1.3 kernel. Supports both RAMOS (in-memory) and persistent (disk-installed) operating modes.

## Features

- **Custom Kernel** — Built on Linux 7.1.3 with optimized configuration for desktop and server use
- **Dual Boot Modes**:
  - **RAMOS** — Runs entirely in memory via squashfs + overlayfs, no disk required
  - **Persistent Install** — Installs to disk with a full Debian Bookworm base
- **TUI Installer** — Ubuntu Server-style text-based installation wizard (dialog-based)
- **Desktop Ready** — KDE Plasma + Wayland in the GUI edition
- **Optimized Boot** — Minimal initramfs (1.2MB), fast squashfs decompression with zstd
- **Read-Write Root** — Overlayfs provides writable root filesystem in RAMOS mode

## Editions

| Edition | Type | Target | Size |
|---------|------|--------|------|
| `complementaryos-release2.0.0-ramos-cli.iso` | RAMOS | CLI (multi-user) | ~437 MB |
| `complementaryos-release2.0.0-ramos-gui.iso` | RAMOS | GUI (graphical) | ~437 MB |
| `complementaryos-release2.0.0.iso` | Persistent | CLI with installer | ~815 MB |
| `complementaryos-release2.0.0-gui.iso` | Persistent | GUI with installer | ~815 MB |

## Prerequisites

To build ComplementaryOS from source, you need:

- **Debian/Ubuntu WSL or native Linux environment**
- **Custom Linux 7.1.3 kernel** compiled at `/home/user/linux-7.1.3/` with:
  - `CONFIG_SQUASHFS=y` and `CONFIG_SQUASHFS_ZSTD=y`
  - `CONFIG_OVERLAY_FS=y`
  - AHCI / NVMe / virtio drivers enabled
- `debootstrap`, `squashfs-tools`, `grub-common`, `grub-pc-bin`, `grub-efi-amd64-bin`, `xorriso`
- `busybox` (static binary for initramfs)
- `zstd` (compression tool)

## Quick Start

### Build from Source

```bash
# Clone the repository
git clone <repo-url> complementaryos
cd complementaryos

# Run the build script
# Note: Requires a pre-built kernel at /home/user/linux-7.1.3/
# and a Debian rootfs at /home/ramos-build/rootfs/
sudo bash optimize-build.sh
```

The script produces four ISO images in the `output/` directory.

### Test with QEMU

```bash
# RAMOS CLI
qemu-system-x86_64 -m 2G -cpu host -smp 2 -enable-kvm \
  -cdrom output/complementaryos-release2.0.0-ramos-cli.iso \
  -nographic -serial mon:stdio

# RAMOS GUI
qemu-system-x86_64 -m 2G -cpu host -smp 2 -enable-kvm \
  -cdrom output/complementaryos-release2.0.0-ramos-gui.iso \
  -vga virtio -display gtk

# Persistent Installer (CLI)
qemu-system-x86_64 -m 2G -cpu host -smp 2 -enable-kvm \
  -cdrom output/complementaryos-release2.0.0.iso \
  -drive file=test-disk.qcow2,format=qcow2,if=virtio \
  -nographic -serial mon:stdio
```

### Test with VMware

1. Create a new VM (Linux > Debian 12 x64)
2. Attach the ISO to the CD/DVD drive
3. Boot from the ISO
4. For RAMOS editions: boot to live desktop or CLI immediately
5. For persistent editions: the installer automatically starts on the VGA console (tty1)

### Default Credentials (RAMOS)

| Field | Value |
|-------|-------|
| Username | `user` |
| Password | `complementary` |
| Hostname | `complementaryos` |

> **Note:** In persistent install mode, the installer prompts you to set a password during installation. The installed system requires sudo password verification.

## Project Structure

```
.
├── optimize-build.sh          # Main build script (v2.0.0)
├── cos-installer-tui.sh       # TUI installer for persistent install
├── install-modules.sh         # Kernel module installation helper
├── update-modules.sh          # Kernel module update helper
├── output/                    # Built ISO images
│   ├── complementaryos-release2.0.0-ramos-cli.iso
│   ├── complementaryos-release2.0.0-ramos-gui.iso
│   ├── complementaryos-release2.0.0.iso
│   └── complementaryos-release2.0.0-gui.iso
├── .gitignore
├── README.md
└── README.zh-CN.md
```

## Build Details

### Build Script: `optimize-build.sh`

The build process consists of six steps:

1. **Trim rootfs** — Remove unnecessary packages, libraries, kernel modules, icons, fonts, and locale data
2. **Optimize systemd** — Disable non-essential services (plymouth, ModemManager, accounts-daemon, etc.)
3. **Create rootfs.squashfs** — Package the full system into a zstd-compressed squashfs image
4. **Create live.squashfs** — Build a minimal live environment containing only the installer and Python runtime
5. **Build initramfs** — Create two initramfs variants (RAMOS and installer) using BusyBox
6. **Build ISO images** — Generate four ISO variants with GRUB bootloader

### TUI Installer: `cos-installer-tui.sh`

The installer provides a step-by-step installation wizard:

1. Keyboard and locale configuration
2. APT mirror selection (USTC, Tsinghua, Aliyun, Huawei, 163, Debian official, or custom)
3. Disk selection and partitioning (automatic or manual with fdisk)
4. User account creation (with password confirmation)
5. SSH server configuration
6. Installation summary and confirmation
7. Partitioning, formatting, and system extraction
8. System configuration (fstab, hostname, GRUB, etc.)
9. Reboot

## License

This project is distributed for educational and personal use. The Debian base system is subject to the Debian Free Software Guidelines (DFSG). Third-party packages are subject to their respective licenses.
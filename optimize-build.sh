#!/bin/bash
# ==============================================================
# ComplementaryOS Build Script v2.0.0
# - RAMOS:  squashfs + overlayfs (rw root)
# - 落盘:   minimal live.squashfs (Python + installer) + system image
# - InitRAMFS 极简优化
# ==============================================================
set -e

BUILD_DIR="/home/ramos-build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
LIVE_DIR="${BUILD_DIR}/live-rootfs"
INITRAMFS_DIR="${BUILD_DIR}/initramfs"
ISO_DIR="${BUILD_DIR}/iso"
OUTPUT_DIR="${BUILD_DIR}/output"
KERNEL_DIR="/home/user/linux-7.1.3"
KERNEL_BZIMAGE="${KERNEL_DIR}/arch/x86/boot/bzImage"
KERNEL_RELEASE=$(cat "${KERNEL_DIR}/include/config/kernel.release" 2>/dev/null || echo "7.1.3")
RELEASE_VER="2.0.0"
BUILD_NUM="262001.001"

echo "=========================================="
echo " ComplementaryOS Build v${RELEASE_VER} Build ${BUILD_NUM}"
echo "=========================================="

# ==============================================================
# Step 1: Trim rootfs for both full system and live installer
# ==============================================================
echo "[1/6] Trimming rootfs (full system)..."
echo "  Rootfs before: $(du -sh ${ROOTFS_DIR} | cut -f1)"

# --- Common trimming (for both full and live) ---
for dir in \
    "${ROOTFS_DIR}/usr/lib/firefox-esr" \
    "${ROOTFS_DIR}/usr/share/ibus" \
    "${ROOTFS_DIR}/usr/share/pocketsphinx" \
    "${ROOTFS_DIR}/usr/lib/cryfs" \
    "${ROOTFS_DIR}/usr/lib/gcc" \
    "${ROOTFS_DIR}/usr/include" \
    "${ROOTFS_DIR}/usr/share/sounds" \
    "${ROOTFS_DIR}/usr/lib/vlc" \
    "${ROOTFS_DIR}/usr/lib/samba" \
    "${ROOTFS_DIR}/usr/lib/git-core" \
    "${ROOTFS_DIR}/usr/lib/aspell" \
    "${ROOTFS_DIR}/usr/lib/bup"; do
    rm -rf "$dir" 2>/dev/null || true
done

# Remove huge libraries
for lib in \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libQt5WebEngineCore.so.5.15.13" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libLLVM-15.so.1" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libz3.so.4" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libgs.so.10.00" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libcodec2.so.1.0" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libx265.so.199" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/libmfxhw64.so.1.35"; do
    rm -f "$lib" 2>/dev/null || true
done

# Remove heavy lib dirs
for dir in \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/dri" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/vdpau" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/gstreamer-1.0" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/vlc" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/samba" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/perl" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/qt5" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/qt5/plugins" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/qt5/qml" \
    "${ROOTFS_DIR}/usr/lib/x86_64-linux-gnu/qt5/plugins/plasma"; do
    rm -rf "$dir" 2>/dev/null || true
done

# Trim kernel modules
echo "  Trimming kernel modules..."
MODULES_DIR="${ROOTFS_DIR}/lib/modules/${KERNEL_RELEASE}"
if [ -d "${MODULES_DIR}" ]; then
    KEEP_MODULES="kernel/fs kernel/lib kernel/crypto kernel/drivers/scsi kernel/drivers/ata kernel/drivers/block kernel/drivers/char kernel/drivers/input kernel/drivers/pci kernel/drivers/virtio kernel/drivers/net kernel/drivers/nvme kernel/drivers/usb/host kernel/arch kernel/drivers/gpu kernel/drivers/video kernel/drivers/hid kernel/drivers/mmc kernel/drivers/md kernel/drivers/nvme"
    for moddir in "${MODULES_DIR}/kernel"/*/; do
        [ -d "$moddir" ] || continue
        modname=$(basename "$moddir")
        keep=0
        for k in $KEEP_MODULES; do
            [ "$k" = "kernel/$modname" ] && keep=1 && break
        done
        [ "$keep" -eq 0 ] && rm -rf "$moddir" 2>/dev/null || true
    done
    depmod -b "${ROOTFS_DIR}" "${KERNEL_RELEASE}" 2>/dev/null || true
fi

# Clean apt cache, logs, python cache
rm -rf "${ROOTFS_DIR}/var/cache/apt" "${ROOTFS_DIR}/var/lib/apt/lists" \
       "${ROOTFS_DIR}/var/lib/apt/periodic" "${ROOTFS_DIR}/var/log" \
       "${ROOTFS_DIR}/var/tmp" 2>/dev/null || true
find "${ROOTFS_DIR}/usr/lib/python3" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "${ROOTFS_DIR}/usr/lib/python3" -name "*.pyc" -o -name "*.pyo" -delete 2>/dev/null || true
rm -rf "${ROOTFS_DIR}/lib/firmware" 2>/dev/null || true
rm -rf "${ROOTFS_DIR}/usr/lib/xorg/modules/drivers" 2>/dev/null || true

# Trim icons (keep only small hicolor)
rm -rf "${ROOTFS_DIR}/usr/share/icons/Adwaita" 2>/dev/null || true
for icon_theme in "${ROOTFS_DIR}/usr/share/icons/"*/; do
    [ -d "$icon_theme" ] || continue
    theme_name=$(basename "$icon_theme")
    [ "$theme_name" != "hicolor" ] && rm -rf "$icon_theme" 2>/dev/null || true
done
for size in 512x512 256x256 128x128 96x96 64x64 48x48; do
    find "${ROOTFS_DIR}/usr/share/icons/hicolor" -type d -name "$size" -exec rm -rf {} + 2>/dev/null || true
done

# Trim fonts, perl, xml, poppler, ghostscript, i18n, X11, desktop-base
rm -rf "${ROOTFS_DIR}/usr/share/fonts" "${ROOTFS_DIR}/usr/share/perl" \
       "${ROOTFS_DIR}/usr/share/perl5" "${ROOTFS_DIR}/usr/share/xml" \
       "${ROOTFS_DIR}/usr/share/poppler" "${ROOTFS_DIR}/usr/share/ghostscript" \
       "${ROOTFS_DIR}/usr/share/desktop-base" 2>/dev/null || true
rm -rf "${ROOTFS_DIR}/usr/share/i18n/locales" 2>/dev/null || true
find "${ROOTFS_DIR}/usr/share/i18n" -type f -name "*.gz" -delete 2>/dev/null || true
rm -rf "${ROOTFS_DIR}/usr/share/X11/xkb" 2>/dev/null || true

echo "  Rootfs after trimming: $(du -sh ${ROOTFS_DIR} | cut -f1)"

# ==============================================================
# Step 2: Fix systemd services for fast boot
# ==============================================================
echo "[2/6] Fixing systemd services..."
mount --bind /proc "${ROOTFS_DIR}/proc" 2>/dev/null || true
mount --bind /sys "${ROOTFS_DIR}/sys" 2>/dev/null || true
mount --bind /dev "${ROOTFS_DIR}/dev" 2>/dev/null || true

chroot "${ROOTFS_DIR}" /bin/bash << 'CHROOTFIX'
export DEBIAN_FRONTEND=noninteractive
apt-get remove -y plymouth plymouth-label 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
for svc in systemd-logind console-setup e2scrub_reap ModemManager \
    accounts-daemon systemd-hostnamed haveged systemd-timesyncd \
    systemd-networkd-wait-online NetworkManager-wait-online; do
    systemctl disable "$svc" 2>/dev/null || true
    systemctl mask "$svc" 2>/dev/null || true
done
sed -i '/\s\/\s/d' /etc/fstab 2>/dev/null || true
mkdir -p /etc/systemd/system/systemd-udevd.service.d/
echo -e "[Service]\nTimeoutStopSec=5s" > /etc/systemd/system/systemd-udevd.service.d/99-timeout.conf
systemctl disable NetworkManager-wait-online 2>/dev/null || true
systemctl mask systemd-networkd-wait-online 2>/dev/null || true
# Set hostname
echo "complementaryos" > /etc/hostname
echo "Systemd services optimized"
CHROOTFIX

for d in dev proc sys; do
    umount -lf "${ROOTFS_DIR}/${d}" 2>/dev/null || true
done

# ==============================================================
# Step 3: Create full rootfs.squashfs (for RAMOS + system image)
# ==============================================================
echo "[3/6] Creating rootfs.squashfs (full system)..."
ROOTFS_SQUASHFS="${BUILD_DIR}/rootfs.squashfs"
rm -f "${ROOTFS_SQUASHFS}"
mksquashfs "${ROOTFS_DIR}" "${ROOTFS_SQUASHFS}" \
    -comp zstd -Xcompression-level 15 \
    -b 1M -no-exports -no-recovery -noappend 2>&1 | tail -3
echo "  rootfs.squashfs: $(du -h ${ROOTFS_SQUASHFS} | cut -f1)"

# ==============================================================
# Step 4: Create minimal live.squashfs (for installer)
# ==============================================================
echo "[4/6] Creating live.squashfs (minimal installer)..."
rm -rf "${LIVE_DIR}"
mkdir -p "${LIVE_DIR}"

# Clone rootfs, then aggressively strip everything except installer essentials
echo "  Cloning rootfs..."
rsync -a "${ROOTFS_DIR}/" "${LIVE_DIR}/" --exclude='proc' --exclude='sys' --exclude='dev' --exclude='tmp' 2>&1 | tail -1

echo "  Stripping live system (keep only Python + installer + storage tools)..."

# Remove desktop environments, GUI, media, dev
for dir in \
    "${LIVE_DIR}/usr/share/plasma" "${LIVE_DIR}/usr/share/kf5" \
    "${LIVE_DIR}/usr/share/kde4" "${LIVE_DIR}/usr/share/sddm" \
    "${LIVE_DIR}/usr/share/wallpapers" "${LIVE_DIR}/usr/share/kxmlgui5" \
    "${LIVE_DIR}/usr/share/kservices5" "${LIVE_DIR}/usr/share/knotifications5" \
    "${LIVE_DIR}/usr/share/kservicetypes5" "${LIVE_DIR}/usr/share/kconfig5" \
    "${LIVE_DIR}/usr/share/kglobalaccel" "${LIVE_DIR}/usr/share/kdeclarative" \
    "${LIVE_DIR}/usr/share/wayland" "${LIVE_DIR}/usr/share/xsessions" \
    "${LIVE_DIR}/usr/share/wayland-sessions" "${LIVE_DIR}/usr/share/applications" \
    "${LIVE_DIR}/usr/share/icons" "${LIVE_DIR}/usr/share/fonts" \
    "${LIVE_DIR}/usr/share/sounds" "${LIVE_DIR}/usr/share/themes" \
    "${LIVE_DIR}/usr/share/backgrounds" "${LIVE_DIR}/usr/share/desktop-base" \
    "${LIVE_DIR}/usr/share/doc" "${LIVE_DIR}/usr/share/man" \
    "${LIVE_DIR}/usr/share/info" "${LIVE_DIR}/usr/share/locale" \
    "${LIVE_DIR}/usr/share/i18n" "${LIVE_DIR}/usr/share/perl" \
    "${LIVE_DIR}/usr/share/perl5" "${LIVE_DIR}/usr/share/xml" \
    "${LIVE_DIR}/usr/share/poppler" "${LIVE_DIR}/usr/share/ghostscript" \
    "${LIVE_DIR}/usr/share/X11" "${LIVE_DIR}/usr/share/qt5" \
    "${LIVE_DIR}/usr/share/qt6" "${LIVE_DIR}/usr/share/glib-2.0/schemas" \
    "${LIVE_DIR}/usr/share/mime" "${LIVE_DIR}/usr/share/color" \
    "${LIVE_DIR}/usr/share/dict" "${LIVE_DIR}/usr/share/geoip" \
    "${LIVE_DIR}/usr/share/hunspell" "${LIVE_DIR}/usr/share/hwdata" \
    "${LIVE_DIR}/usr/share/libdrm" "${LIVE_DIR}/usr/share/libgweather" \
    "${LIVE_DIR}/usr/share/libtool" "${LIVE_DIR}/usr/share/locales" \
    "${LIVE_DIR}/usr/share/pixmaps" "${LIVE_DIR}/usr/share/ppd" \
    "${LIVE_DIR}/usr/share/texlive" "${LIVE_DIR}/usr/share/vulkan" \
    "${LIVE_DIR}/usr/share/zsh" "${LIVE_DIR}/usr/share/bash-completion" \
    "${LIVE_DIR}/usr/share/gdb" "${LIVE_DIR}/usr/share/gtk-doc" \
    "${LIVE_DIR}/usr/share/help" "${LIVE_DIR}/usr/share/alsa" \
    "${LIVE_DIR}/usr/share/polkit-1" "${LIVE_DIR}/usr/share/pam" \
    "${LIVE_DIR}/usr/share/dbus-1" "${LIVE_DIR}/usr/share/gobject-introspection-1.0" \
    "${LIVE_DIR}/usr/share/gettext" "${LIVE_DIR}/usr/share/iso-codes" \
    "${LIVE_DIR}/usr/share/language-selector" "${LIVE_DIR}/usr/share/lintian" \
    "${LIVE_DIR}/usr/share/metainfo" "${LIVE_DIR}/usr/share/packagekit" \
    "${LIVE_DIR}/usr/share/pkgconfig" "${LIVE_DIR}/usr/share/sgml" \
    "${LIVE_DIR}/usr/share/tcltk" "${LIVE_DIR}/usr/share/thumbnailers" \
    "${LIVE_DIR}/usr/share/zoneinfo" "${LIVE_DIR}/usr/share/libdvdnav" \
    "${LIVE_DIR}/usr/share/libdvdread" "${LIVE_DIR}/usr/share/libdvdcss" \
    "${LIVE_DIR}/usr/share/vala" "${LIVE_DIR}/usr/share/yelp" \
    "${LIVE_DIR}/usr/share/openal" "${LIVE_DIR}/usr/share/sdl" \
    "${LIVE_DIR}/usr/share/speech-dispatcher" "${LIVE_DIR}/usr/share/mythes" \
    "${LIVE_DIR}/usr/share/enchant" "${LIVE_DIR}/usr/share/glib-2.0" \
    "${LIVE_DIR}/usr/share/GConf" "${LIVE_DIR}/usr/share/gconf" \
    "${LIVE_DIR}/usr/share/cups" "${LIVE_DIR}/usr/share/cups" \
    "${LIVE_DIR}/usr/share/colord" "${LIVE_DIR}/usr/share/geoclue" \
    "${LIVE_DIR}/usr/share/gnupg" "${LIVE_DIR}/usr/share/gssdp" \
    "${LIVE_DIR}/usr/share/gtk-3.0" "${LIVE_DIR}/usr/share/gtk-4.0" \
    "${LIVE_DIR}/usr/share/im-config" "${LIVE_DIR}/usr/share/initramfs-tools" \
    "${LIVE_DIR}/usr/share/java" "${LIVE_DIR}/usr/share/libgweather" \
    "${LIVE_DIR}/usr/share/libwacom" "${LIVE_DIR}/usr/share/locale" \
    "${LIVE_DIR}/usr/share/modemmanager" "${LIVE_DIR}/usr/share/nano" \
    "${LIVE_DIR}/usr/share/omf" "${LIVE_DIR}/usr/share/openvpn" \
    "${LIVE_DIR}/usr/share/p11-kit" "${LIVE_DIR}/usr/share/papi" \
    "${LIVE_DIR}/usr/share/php" "${LIVE_DIR}/usr/share/psplash" \
    "${LIVE_DIR}/usr/share/python3" "${LIVE_DIR}/usr/share/qemu" \
    "${LIVE_DIR}/usr/share/readline" "${LIVE_DIR}/usr/share/samba" \
    "${LIVE_DIR}/usr/share/sane" "${LIVE_DIR}/usr/share/sgml" \
    "${LIVE_DIR}/usr/share/shared-info" "${LIVE_DIR}/usr/share/sounds" \
    "${LIVE_DIR}/usr/share/ssh" "${LIVE_DIR}/usr/share/sudo" \
    "${LIVE_DIR}/usr/share/symlinks" "${LIVE_DIR}/usr/share/systemd" \
    "${LIVE_DIR}/usr/share/tabset" "${LIVE_DIR}/usr/share/tcl8.6" \
    "${LIVE_DIR}/usr/share/terminfo" "${LIVE_DIR}/usr/share/tk8.6" \
    "${LIVE_DIR}/usr/share/usb_modeswitch" "${LIVE_DIR}/usr/share/vim" \
    "${LIVE_DIR}/usr/share/w3m" "${LIVE_DIR}/usr/share/wget" \
    "${LIVE_DIR}/usr/share/xml-core" "${LIVE_DIR}/usr/share/xorg" \
    "${LIVE_DIR}/usr/share/xul-ext" "${LIVE_DIR}/usr/share/xview" \
    "${LIVE_DIR}/usr/share/zsh" "${LIVE_DIR}/usr/share/apt" \
    "${LIVE_DIR}/usr/share/base-files" "${LIVE_DIR}/usr/share/base-passwd" \
    "${LIVE_DIR}/usr/share/bash-completion" "${LIVE_DIR}/usr/share/binfmts" \
    "${LIVE_DIR}/usr/share/ca-certificates" "${LIVE_DIR}/usr/share/common-licenses" \
    "${LIVE_DIR}/usr/share/cracklib" "${LIVE_DIR}/usr/share/debconf" \
    "${LIVE_DIR}/usr/share/debianutils" "${LIVE_DIR}/usr/share/dpkg" \
    "${LIVE_DIR}/usr/share/e2fsprogs" "${LIVE_DIR}/usr/share/ed" \
    "${LIVE_DIR}/usr/share/file" "${LIVE_DIR}/usr/share/findutils" \
    "${LIVE_DIR}/usr/share/gawk" "${LIVE_DIR}/usr/share/gcc" \
    "${LIVE_DIR}/usr/share/gdb" "${LIVE_DIR}/usr/share/gdbm" \
    "${LIVE_DIR}/usr/share/genisoimage" "${LIVE_DIR}/usr/share/git-core" \
    "${LIVE_DIR}/usr/share/groff" "${LIVE_DIR}/usr/share/grub" \
    "${LIVE_DIR}/usr/share/gzip" "${LIVE_DIR}/usr/share/hostname" \
    "${LIVE_DIR}/usr/share/icu" "${LIVE_DIR}/usr/share/iptables" \
    "${LIVE_DIR}/usr/share/kmod" "${LIVE_DIR}/usr/share/ldap" \
    "${LIVE_DIR}/usr/share/less" "${LIVE_DIR}/usr/share/libc-bin" \
    "${LIVE_DIR}/usr/share/lintian" "${LIVE_DIR}/usr/share/login" \
    "${LIVE_DIR}/usr/share/logrotate" "${LIVE_DIR}/usr/share/lsb" \
    "${LIVE_DIR}/usr/share/lsof" "${LIVE_DIR}/usr/share/lvm2" \
    "${LIVE_DIR}/usr/share/m4" "${LIVE_DIR}/usr/share/mailutils" \
    "${LIVE_DIR}/usr/share/make" "${LIVE_DIR}/usr/share/man-db" \
    "${LIVE_DIR}/usr/share/mawk" "${LIVE_DIR}/usr/share/mc" \
    "${LIVE_DIR}/usr/share/misc" "${LIVE_DIR}/usr/share/nano" \
    "${LIVE_DIR}/usr/share/netbase" "${LIVE_DIR}/usr/share/nfs-common" \
    "${LIVE_DIR}/usr/share/npth" "${LIVE_DIR}/usr/share/ntp" \
    "${LIVE_DIR}/usr/share/openldap" "${LIVE_DIR}/usr/share/openssh" \
    "${LIVE_DIR}/usr/share/openssl" "${LIVE_DIR}/usr/share/os-prober" \
    "${LIVE_DIR}/usr/share/p11-kit" "${LIVE_DIR}/usr/share/pam" \
    "${LIVE_DIR}/usr/share/pam-configs" "${LIVE_DIR}/usr/share/patch" \
    "${LIVE_DIR}/usr/share/pciutils" "${LIVE_DIR}/usr/share/perl" \
    "${LIVE_DIR}/usr/share/pkgconfig" "${LIVE_DIR}/usr/share/popt" \
    "${LIVE_DIR}/usr/share/psmisc" "${LIVE_DIR}/usr/share/python" \
    "${LIVE_DIR}/usr/share/python3" "${LIVE_DIR}/usr/share/readline" \
    "${LIVE_DIR}/usr/share/recode" "${LIVE_DIR}/usr/share/resolvconf" \
    "${LIVE_DIR}/usr/share/rsync" "${LIVE_DIR}/usr/share/sed" \
    "${LIVE_DIR}/usr/share/sensible-utils" "${LIVE_DIR}/usr/share/shadow" \
    "${LIVE_DIR}/usr/share/smartmontools" "${LIVE_DIR}/usr/share/socat" \
    "${LIVE_DIR}/usr/share/sort" \
    "${LIVE_DIR}/usr/share/speech-dispatcher" \
    "${LIVE_DIR}/usr/share/sqlite3" "${LIVE_DIR}/usr/share/sysvinit" \
    "${LIVE_DIR}/usr/share/tar" "${LIVE_DIR}/usr/share/tcpdump" \
    "${LIVE_DIR}/usr/share/tcpd" "${LIVE_DIR}/usr/share/tex-common" \
    "${LIVE_DIR}/usr/share/texinfo" "${LIVE_DIR}/usr/share/time" \
    "${LIVE_DIR}/usr/share/u-boot" "${LIVE_DIR}/usr/share/ucf" \
    "${LIVE_DIR}/usr/share/udev" "${LIVE_DIR}/usr/share/unattended-upgrades" \
    "${LIVE_DIR}/usr/share/unzip" "${LIVE_DIR}/usr/share/usb.ids" \
    "${LIVE_DIR}/usr/share/usbutils" "${LIVE_DIR}/usr/share/util-linux" \
    "${LIVE_DIR}/usr/share/wget" "${LIVE_DIR}/usr/share/whiptail" \
    "${LIVE_DIR}/usr/share/x11" "${LIVE_DIR}/usr/share/xml-core" \
    "${LIVE_DIR}/usr/share/xorg" "${LIVE_DIR}/usr/share/xserver-xorg" \
    "${LIVE_DIR}/usr/share/xtables" "${LIVE_DIR}/usr/share/xxd" \
    "${LIVE_DIR}/usr/share/xz" "${LIVE_DIR}/usr/share/zip" \
    "${LIVE_DIR}/usr/share/zlib" "${LIVE_DIR}/usr/share/zsh"; do
    rm -rf "$dir" 2>/dev/null || true
done

# Remove heavy lib dirs from live system
for dir in \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/dri" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/vdpau" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/gstreamer-1.0" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/vlc" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/samba" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/perl" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/qt5" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/qt5/plugins" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/qt5/qml" \
    "${LIVE_DIR}/usr/lib/x86_64-linux-gnu/qt5/plugins/plasma" \
    "${LIVE_DIR}/usr/lib/xorg" \
    "${LIVE_DIR}/usr/lib/python3.11/test" \
    "${LIVE_DIR}/usr/lib/python3.11/idlelib" \
    "${LIVE_DIR}/usr/lib/python3.11/turtledemo" \
    "${LIVE_DIR}/usr/lib/python3.11/lib2to3" \
    "${LIVE_DIR}/usr/lib/python3.11/distutils" \
    "${LIVE_DIR}/usr/lib/python3.11/ensurepip" \
    "${LIVE_DIR}/usr/lib/python3.11/pydoc_data" \
    "${LIVE_DIR}/usr/lib/aspell" \
    "${LIVE_DIR}/usr/lib/gcc" \
    "${LIVE_DIR}/usr/lib/git-core" \
    "${LIVE_DIR}/usr/lib/firefox-esr" \
    "${LIVE_DIR}/usr/lib/cryfs"; do
    rm -rf "$dir" 2>/dev/null || true
done

# Remove all kernel modules from live (keep only storage + fs)
echo "  Trimming live kernel modules..."
LIVE_MODULES="${LIVE_DIR}/lib/modules/${KERNEL_RELEASE}"
if [ -d "${LIVE_MODULES}" ]; then
    LIVE_KEEP="kernel/drivers/scsi kernel/drivers/ata kernel/drivers/block kernel/drivers/char kernel/drivers/pci kernel/drivers/virtio kernel/drivers/nvme kernel/drivers/usb/host kernel/fs kernel/lib kernel/crypto kernel/drivers/input kernel/drivers/hid kernel/drivers/md"
    for moddir in "${LIVE_MODULES}/kernel"/*/; do
        [ -d "$moddir" ] || continue
        modname=$(basename "$moddir")
        keep=0
        for k in $LIVE_KEEP; do
            [ "$k" = "kernel/$modname" ] && keep=1 && break
        done
        [ "$keep" -eq 0 ] && rm -rf "$moddir" 2>/dev/null || true
    done
    depmod -b "${LIVE_DIR}" "${KERNEL_RELEASE}" 2>/dev/null || true
fi

# Clean python cache
find "${LIVE_DIR}/usr/lib/python3" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find "${LIVE_DIR}/usr/lib/python3" -name "*.pyc" -o -name "*.pyo" -delete 2>/dev/null || true
rm -rf "${LIVE_DIR}/var/cache" "${LIVE_DIR}/var/log" "${LIVE_DIR}/var/tmp" \
       "${LIVE_DIR}/var/lib/apt" 2>/dev/null || true
rm -rf "${LIVE_DIR}/lib/firmware" 2>/dev/null || true

# Copy installer script
echo "  Copying installer script..."
mkdir -p "${LIVE_DIR}/usr/local/bin"
cp "$(dirname "$0")/cos-installer-tui.sh" "${LIVE_DIR}/usr/local/bin/cos-installer"
chmod +x "${LIVE_DIR}/usr/local/bin/cos-installer"

# Create auto-installer service
echo "  Creating auto-installer service..."
mkdir -p "${LIVE_DIR}/etc/systemd/system"
cat > "${LIVE_DIR}/etc/systemd/system/cos-auto-installer.service" << 'SERVICEEOF'
[Unit]
Description=ComplementaryOS Auto Installer
After=local-fs.target systemd-udev-settle.service getty.target
Requires=systemd-udev-settle.service
Conflicts=getty@tty1.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 2
ExecStart=/usr/local/bin/cos-installer --tui
StandardInput=tty-force
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TimeoutStartSec=infinity
SendSIGHUP=yes

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable the service (ensure /dev/null exists in chroot first)
mkdir -p "${LIVE_DIR}/dev"
[ -e "${LIVE_DIR}/dev/null" ] || mknod -m 666 "${LIVE_DIR}/dev/null" c 1 3
[ -e "${LIVE_DIR}/dev/random" ] || mknod -m 666 "${LIVE_DIR}/dev/random" c 1 8
chroot "${LIVE_DIR}" /bin/bash -c "systemctl enable cos-auto-installer" 2>&1
echo "  Done: cos-auto-installer.service enabled"

# Create a simple /.live marker
touch "${LIVE_DIR}/.live"

echo "  Live rootfs size: $(du -sh ${LIVE_DIR} | cut -f1)"

# Create live.squashfs
LIVE_SQUASHFS="${BUILD_DIR}/live.squashfs"
rm -f "${LIVE_SQUASHFS}"
mksquashfs "${LIVE_DIR}" "${LIVE_SQUASHFS}" \
    -comp zstd -Xcompression-level 15 \
    -b 1M -no-exports -no-recovery -noappend 2>&1 | tail -3
echo "  live.squashfs: $(du -h ${LIVE_SQUASHFS} | cut -f1)"

# ==============================================================
# Step 5: Create initramfs (shared by all modes, mode selected by kernel arg)
# ==============================================================
echo "[5/6] Creating initramfs..."

build_initramfs() {
    local MODE="$1"  # "ramos" or "install"
    local OUT="${BUILD_DIR}/initrd-${MODE}.img"

    rm -rf "${INITRAMFS_DIR}"
    mkdir -p "${INITRAMFS_DIR}/bin" "${INITRAMFS_DIR}/sbin" "${INITRAMFS_DIR}/etc" \
        "${INITRAMFS_DIR}/dev" "${INITRAMFS_DIR}/lib" "${INITRAMFS_DIR}/lib64" \
        "${INITRAMFS_DIR}/proc" "${INITRAMFS_DIR}/sys" "${INITRAMFS_DIR}/newroot" \
        "${INITRAMFS_DIR}/mnt" "${INITRAMFS_DIR}/root" "${INITRAMFS_DIR}/run" \
        "${INITRAMFS_DIR}/tmp" "${INITRAMFS_DIR}/usr/bin" "${INITRAMFS_DIR}/usr/sbin"

    cp /usr/bin/busybox "${INITRAMFS_DIR}/bin/busybox"
    for applet in mount mkdir modprobe sleep sh cat echo ls mv cp rm chmod chown \
        ln readlink switch_root losetup grep date umount; do
        ln -sf busybox "${INITRAMFS_DIR}/bin/${applet}"
    done

    /bin/busybox mknod "${INITRAMFS_DIR}/dev/null" c 1 3
    /bin/busybox chmod 666 "${INITRAMFS_DIR}/dev/null"
    /bin/busybox mknod "${INITRAMFS_DIR}/dev/console" c 5 1
    /bin/busybox chmod 666 "${INITRAMFS_DIR}/dev/console"

    # Copy overlay.ko module into initramfs
    local OVERLAY_MOD="${ROOTFS_DIR}/lib/modules/${KERNEL_RELEASE}/kernel/fs/overlayfs/overlay.ko"
    if [ -f "${OVERLAY_MOD}" ]; then
        mkdir -p "${INITRAMFS_DIR}/lib/modules"
        cp "${OVERLAY_MOD}" "${INITRAMFS_DIR}/lib/modules/"
    fi

    # Build init script based on mode
    if [ "${MODE}" = "ramos" ]; then
        cat > "${INITRAMFS_DIR}/init" << 'RINITEOF'
#!/bin/busybox sh

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "=== ComplementaryOS v2.0.0 Build 262001.001 (RAMOS) ==="
date 2>/dev/null || true

/bin/busybox mount -t proc  none /proc 2>&1
/bin/busybox mount -t sysfs none /sys 2>&1
/bin/busybox mount -t devtmpfs none /dev 2>&1
/bin/busybox mkdir -p /dev/shm /dev/pts 2>&1
/bin/busybox mount -t devpts none /dev/pts 2>&1
/bin/busybox mount -t tmpfs none /dev/shm 2>&1

# Mount tmpfs for mount points (ISO is read-only)
/bin/busybox mount -t tmpfs -o size=128M tmpfs /tmp

/bin/busybox modprobe -a ahci libahci ata_piix vmw_pvscsi virtio_blk virtio_pci 2>/dev/null || true

# Load overlay module
/bin/busybox insmod /lib/modules/overlay.ko 2>/dev/null || /bin/busybox modprobe overlay 2>/dev/null || true

# Scan for ISO (max 3s)
for i in 0 1 2; do
    for dev in sr0 sr1 sr2 hdc; do
        if [ -b "/dev/${dev}" ] && /bin/busybox mount -t iso9660 -o ro "/dev/${dev}" /mnt 2>&1; then
            BOOT_DEVICE="/dev/${dev}"
            break 2
        fi
    done
    [ -z "${BOOT_DEVICE}" ] && /bin/busybox sleep 1
done

[ -z "${BOOT_DEVICE}" ] && echo "ERROR: No boot device" && /bin/busybox sh

# Find rootfs.squashfs
SQUASHFS=""
for f in /mnt/rootfs.squashfs /mnt/filesystem.squashfs; do
    [ -f "$f" ] && SQUASHFS="$f" && break
done
[ -z "${SQUASHFS}" ] && echo "ERROR: rootfs.squashfs not found" && /bin/busybox sh

echo "Mounting squashfs: ${SQUASHFS}"

# Setup overlayfs: lower=squashfs, upper=tmpfs (use /tmp not /mnt)
mkdir -p /tmp/root /tmp/upper /tmp/work
LOOP_DEV=$(/bin/busybox losetup -f)
/bin/busybox losetup "${LOOP_DEV}" "${SQUASHFS}"
/bin/busybox mount -t squashfs -o ro "${LOOP_DEV}" /tmp/root

/bin/busybox mount -t tmpfs -o size=1G,mode=755 tmpfs /tmp/upper
mkdir -p /tmp/upper/upper /tmp/upper/work

/bin/busybox mount -t overlay overlay \
    -o lowerdir=/tmp/root,upperdir=/tmp/upper/upper,workdir=/tmp/upper/work \
    /newroot

if [ ! -f /newroot/sbin/init ] && [ ! -f /newroot/lib/systemd/systemd ]; then
    echo "ERROR: Overlay mount failed!"
    /bin/busybox sh
fi

# Copy squashfs to /run for installer
mkdir -p /newroot/run
/bin/busybox cp "${SQUASHFS}" /newroot/run/rootfs.squashfs 2>&1 || true

# Move mounts (create dirs first)
/bin/busybox mkdir -p /newroot/proc /newroot/sys /newroot/dev
/bin/busybox mount --move /proc /newroot/proc 2>&1
/bin/busybox mount --move /sys /newroot/sys 2>&1
/bin/busybox mount --move /dev /newroot/dev 2>&1
/bin/busybox umount /mnt 2>/dev/null || true

date 2>/dev/null || true
echo "Starting systemd (rw root via overlayfs)..."
exec /bin/busybox switch_root /newroot /sbin/init 2>&1

echo "ERROR: switch_root failed!"
/bin/busybox sh
RINITEOF

    else
        # INSTALL mode: minimal initramfs, boots into live.squashfs
        cat > "${INITRAMFS_DIR}/init" << 'IINITEOF'
#!/bin/busybox sh

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

echo "=== ComplementaryOS v2.0.0 Build 262001.001 (Installer) ==="
date 2>/dev/null || true

/bin/busybox mount -t proc  none /proc 2>&1
/bin/busybox mount -t sysfs none /sys 2>&1
/bin/busybox mount -t devtmpfs none /dev 2>&1

# Mount tmpfs for mount points
/bin/busybox mount -t tmpfs -o size=128M tmpfs /tmp

/bin/busybox modprobe -a ahci libahci ata_piix vmw_pvscsi virtio_blk virtio_pci 2>/dev/null || true

# Load overlay module
/bin/busybox insmod /lib/modules/overlay.ko 2>/dev/null || /bin/busybox modprobe overlay 2>/dev/null || true

# Scan for ISO (max 3s)
for i in 0 1 2; do
    for dev in sr0 sr1 sr2 hdc; do
        if [ -b "/dev/${dev}" ] && /bin/busybox mount -t iso9660 -o ro "/dev/${dev}" /mnt 2>&1; then
            BOOT_DEVICE="/dev/${dev}"
            break 2
        fi
    done
    [ -z "${BOOT_DEVICE}" ] && /bin/busybox sleep 1
done

[ -z "${BOOT_DEVICE}" ] && echo "ERROR: No boot device found" && /bin/busybox sh

echo "ISO mounted at ${BOOT_DEVICE}"

# Mount live.squashfs (minimal installer system)
if [ -f /mnt/live.squashfs ]; then
    echo "Mounting live.squashfs..."
    mkdir -p /tmp/live /tmp/upper /tmp/work
    LOOP_DEV=$(/bin/busybox losetup -f)
    /bin/busybox losetup "${LOOP_DEV}" /mnt/live.squashfs
    /bin/busybox mount -t squashfs -o ro "${LOOP_DEV}" /tmp/live

    # Overlay for rw root (512M for live system)
    /bin/busybox mount -t tmpfs -o size=512M,mode=755 tmpfs /tmp/upper
    mkdir -p /tmp/upper/upper /tmp/upper/work
    /bin/busybox mount -t overlay overlay \
        -o lowerdir=/tmp/live,upperdir=/tmp/upper/upper,workdir=/tmp/upper/work \
        /newroot

    if [ ! -f /newroot/sbin/init ] && [ ! -f /newroot/lib/systemd/systemd ]; then
        echo "ERROR: live.squashfs mount failed!"
        /bin/busybox sh
    fi
else
    echo "ERROR: live.squashfs not found on ISO!"
    /bin/busybox ls /mnt/
    /bin/busybox sh
fi

# Copy rootfs.squashfs (system image) - accessible via /mnt/rootfs.squashfs
# No need to copy to /run (too large for tmpfs)

# Move mounts (create dirs first)
/bin/busybox mkdir -p /newroot/proc /newroot/sys /newroot/dev
/bin/busybox mount --move /proc /newroot/proc 2>&1
/bin/busybox mount --move /sys /newroot/sys 2>&1
/bin/busybox mount --move /dev /newroot/dev 2>&1

# Keep ISO mounted for installer access
/bin/busybox mkdir -p /newroot/mnt
/bin/busybox mount --move /mnt /newroot/mnt 2>&1

date 2>/dev/null || true
echo "Starting live system (auto-installer)..."
exec /bin/busybox switch_root /newroot /sbin/init 2>&1

echo "ERROR: switch_root failed!"
/bin/busybox sh
IINITEOF
    fi

    chmod 755 "${INITRAMFS_DIR}/init"

    cd "${INITRAMFS_DIR}"
    find . -print0 | /bin/busybox cpio -0 -o -H newc --quiet 2>/dev/null | gzip > "${OUT}"
    echo "  initrd-${MODE}.img: $(du -h ${OUT} | cut -f1)"
}

build_initramfs "ramos"
build_initramfs "install"

# ==============================================================
# Step 6: Build ISO images
# ==============================================================
echo "[6/6] Building ISO images..."

build_ramos_iso() {
    local NAME="$1"
    local GRUB_EXTRA="$2"
    local TARGET="$3"
    local ISO_FILE="${OUTPUT_DIR}/complementaryos-release${RELEASE_VER}-${NAME}.iso"

    rm -rf "${ISO_DIR}"
    mkdir -p "${ISO_DIR}/boot/grub"

    cp "${KERNEL_BZIMAGE}" "${ISO_DIR}/boot/vmlinuz"
    cp "${BUILD_DIR}/initrd-ramos.img" "${ISO_DIR}/boot/initrd.img"
    cp "${ROOTFS_SQUASHFS}" "${ISO_DIR}/rootfs.squashfs"

    cat > "${ISO_DIR}/boot/grub/grub.cfg" << GRUBEOF
set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod ext2
insmod iso9660
insmod fat
insmod all_video

menuentry "ComplementaryOS v${RELEASE_VER} Build ${BUILD_NUM} - RAMOS ${TARGET}" {
    set gfxpayload=keep
    linux /boot/vmlinuz root=/dev/ram0 rw console=ttyS0,115200 console=tty0 loglevel=3 udev.log_level=3 nokaslr ${GRUB_EXTRA}
    initrd /boot/initrd.img
}

menuentry "ComplementaryOS RAMOS - Debug Mode" {
    set gfxpayload=keep
    linux /boot/vmlinuz root=/dev/ram0 rw console=ttyS0,115200 console=tty0 loglevel=8 debug nokaslr
    initrd /boot/initrd.img
}

menuentry "Reboot" { reboot }
menuentry "Shutdown" { halt }
GRUBEOF

    echo "Building: ${ISO_FILE}"
    grub-mkrescue -o "${ISO_FILE}" "${ISO_DIR}" \
      --modules="part_gpt part_msdos iso9660 fat ext2" \
      --locales="" --themes="" --fonts="" 2>&1 | tail -1
    echo "  Size: $(du -h "${ISO_FILE}" | cut -f1)"
}

build_install_iso() {
    local NAME="$1"
    local GRUB_EXTRA="$2"
    local TARGET="$3"
    local SUFFIX=""
    [ -n "${NAME}" ] && SUFFIX="-${NAME}" || SUFFIX=""
    local ISO_FILE="${OUTPUT_DIR}/complementaryos-release${RELEASE_VER}${SUFFIX}.iso"

    rm -rf "${ISO_DIR}"
    mkdir -p "${ISO_DIR}/boot/grub"

    cp "${KERNEL_BZIMAGE}" "${ISO_DIR}/boot/vmlinuz"
    cp "${BUILD_DIR}/initrd-install.img" "${ISO_DIR}/boot/initrd.img"
    cp "${LIVE_SQUASHFS}" "${ISO_DIR}/live.squashfs"
    cp "${ROOTFS_SQUASHFS}" "${ISO_DIR}/rootfs.squashfs"

    cat > "${ISO_DIR}/boot/grub/grub.cfg" << GRUBEOF
set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod ext2
insmod iso9660
insmod fat
insmod all_video

menuentry "ComplementaryOS v${RELEASE_VER} Build ${BUILD_NUM} - Install ${TARGET}" {
    set gfxpayload=keep
    linux /boot/vmlinuz root=/dev/ram0 rw console=ttyS0,115200 console=tty0 loglevel=3 udev.log_level=3 nokaslr ${GRUB_EXTRA}
    initrd /boot/initrd.img
}

menuentry "ComplementaryOS Installer - Debug Mode" {
    set gfxpayload=keep
    linux /boot/vmlinuz root=/dev/ram0 rw console=ttyS0,115200 console=tty0 loglevel=8 debug nokaslr
    initrd /boot/initrd.img
}

menuentry "Reboot" { reboot }
menuentry "Shutdown" { halt }
GRUBEOF

    echo "Building: ${ISO_FILE}"
    grub-mkrescue -o "${ISO_FILE}" "${ISO_DIR}" \
      --modules="part_gpt part_msdos iso9660 fat ext2" \
      --locales="" --themes="" --fonts="" 2>&1 | tail -1
    echo "  Size: $(du -h "${ISO_FILE}" | cut -f1)"
}

# Build RAMOS editions
build_ramos_iso "ramos-cli" "systemd.set-default=multi-user.target" "CLI"
build_ramos_iso "ramos-gui" "systemd.set-default=graphical.target" "GUI"

# Build 落盘 (installer) editions
build_install_iso "" "systemd.set-default=multi-user.target" "CLI"
build_install_iso "gui" "systemd.set-default=graphical.target" "GUI"

echo ""
echo "=========================================="
echo " Build Complete!"
echo "=========================================="
echo " Version: ${RELEASE_VER} Build ${BUILD_NUM}"
echo ""
echo " Output files:"
ls -lh "${OUTPUT_DIR}/complementaryos-release${RELEASE_VER}"*.iso 2>/dev/null
echo ""
echo "rootfs.squashfs: $(du -h ${ROOTFS_SQUASHFS} | cut -f1)"
echo "live.squashfs:   $(du -h ${LIVE_SQUASHFS} | cut -f1)"
echo "initrd-ramos.img:   $(du -h ${BUILD_DIR}/initrd-ramos.img | cut -f1)"
echo "initrd-install.img: $(du -h ${BUILD_DIR}/initrd-install.img | cut -f1)"
echo "=========================================="
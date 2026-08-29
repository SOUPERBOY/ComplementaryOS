#!/bin/bash
# ==============================================================
# ComplementaryOS TUI Installer
# Ubuntu Server-style installation wizard using dialog
# ==============================================================

# --- Configuration ---
VERSION="1.0.0"
LOG_FILE="/tmp/cos-installer.log"

# Default values
HOSTNAME="complementaryos"
USERNAME="user"
USER_PASSWORD=""
CONFIRM_PASSWORD=""
DISK=""
BOOT_MODE="bios"
PARTITION_SCHEME="auto"  # auto or manual
MIRROR="https://mirrors.ustc.edu.cn/debian"
MIRROR_NAME="USTC (China)"
MIRROR_SECURITY="https://mirrors.ustc.edu.cn/debian-security"
ENABLE_SSH="yes"
SSH_PORT="22"
LOCALE="en_US.UTF-8"
KEYBOARD="us"
TIMEZONE="Asia/Shanghai"
INSTALL_DEV_APPS="no"

# --- Dialog setup ---
export DIALOGRC="/dev/null"
export DIALOGOPTS="--colors --backtitle 'ComplementaryOS ${VERSION} Installer'"

# --- Helper functions ---
log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

cleanup() {
    # Unmount any mounted partitions
    for mp in /mnt/target /mnt/target/boot /mnt/target/boot/efi /mnt/target/proc /mnt/target/sys /mnt/target/dev /mnt/target/dev/pts; do
        umount -lf "$mp" 2>/dev/null || true
    done
    # Remove any device mapper mappings
    dmsetup remove_all 2>/dev/null || true
}

die() {
    dialog --title "FATAL ERROR" --msgbox "$1\n\nSee ${LOG_FILE} for details." 10 60
    cleanup
    exit 1
}

# --- Step 1: Welcome ---
welcome() {
    dialog --title "ComplementaryOS ${VERSION}" \
        --msgbox "\n\Z1╔══════════════════════════════════════╗\Zn
\Z1║\Zn      \Zb\Z4ComplementaryOS Installer\Zn      \Z1║\Zn
\Z1╚══════════════════════════════════════╝\Zn

This wizard will guide you through installing
ComplementaryOS to your hard disk.

Features:
• Automatic or manual partitioning
• Multiple mirror selection
• SSH server configuration
• UEFI and Legacy BIOS support

\ZbNote:\Zn This will ERASE the selected disk.
Make sure you have backups!" 20 60
}

# --- Step 2: Keyboard / Locale ---
configure_locale() {
    KEYBOARD=$(dialog --title "Keyboard Layout" \
        --menu "Choose your keyboard layout:" 14 50 5 \
        "us" "United States (default)" \
        "gb" "United Kingdom" \
        "de" "Germany" \
        "fr" "France" \
        "jp" "Japan" \
        "cn" "China" \
        "br" "Brazil" \
        "it" "Italy" \
        "es" "Spain" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1

    TIMEZONE=$(dialog --title "Time Zone" \
        --menu "Select your time zone:" 14 50 6 \
        "Asia/Shanghai" "China Standard Time (default)" \
        "Asia/Tokyo" "Japan - Tokyo" \
        "Asia/Singapore" "Singapore" \
        "America/New_York" "US - Eastern" \
        "America/Los_Angeles" "US - Pacific" \
        "Europe/London" "UK - London" \
        "Europe/Berlin" "Germany - Berlin" \
        "UTC" "Coordinated Universal Time" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1
}

# --- Step 3: Mirror Selection ---
configure_mirror() {
    MIRROR_CHOICE=$(dialog --title "APT Mirror Selection" \
        --menu "Choose a Debian mirror for package installation:" 16 65 8 \
        "USTC" "mirrors.ustc.edu.cn (China, recommended)" \
        "Tsinghua" "mirrors.tuna.tsinghua.edu.cn (China)" \
        "Aliyun" "mirrors.aliyun.com (China)" \
        "Huawei" "mirrors.huaweicloud.com (China)" \
        "163" "mirrors.163.com (China)" \
        "Debian" "deb.debian.org (Official, worldwide)" \
        "Custom" "Enter a custom mirror URL" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1

    case "$MIRROR_CHOICE" in
        USTC)
            MIRROR="https://mirrors.ustc.edu.cn/debian"
            MIRROR_SECURITY="https://mirrors.ustc.edu.cn/debian-security"
            MIRROR_NAME="USTC (China)"
            ;;
        Tsinghua)
            MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian"
            MIRROR_SECURITY="https://mirrors.tuna.tsinghua.edu.cn/debian-security"
            MIRROR_NAME="Tsinghua (China)"
            ;;
        Aliyun)
            MIRROR="https://mirrors.aliyun.com/debian"
            MIRROR_SECURITY="https://mirrors.aliyun.com/debian-security"
            MIRROR_NAME="Aliyun (China)"
            ;;
        Huawei)
            MIRROR="https://mirrors.huaweicloud.com/debian"
            MIRROR_SECURITY="https://mirrors.huaweicloud.com/debian-security"
            MIRROR_NAME="Huawei (China)"
            ;;
        163)
            MIRROR="https://mirrors.163.com/debian"
            MIRROR_SECURITY="https://mirrors.163.com/debian-security"
            MIRROR_NAME="163 (China)"
            ;;
        Debian)
            MIRROR="https://deb.debian.org/debian"
            MIRROR_SECURITY="https://security.debian.org/debian-security"
            MIRROR_NAME="Official Debian"
            ;;
        Custom)
            MIRROR=$(dialog --title "Custom Mirror" \
                --inputbox "Enter Debian mirror URL:" 8 60 "https://mirrors.ustc.edu.cn/debian" \
                3>&1 1>&2 2>&3)
            [ $? -ne 0 ] && return 1
            MIRROR_SECURITY=$(dialog --title "Security Mirror" \
                --inputbox "Enter security mirror URL:" 8 60 "https://mirrors.ustc.edu.cn/debian-security" \
                3>&1 1>&2 2>&3)
            [ $? -ne 0 ] && return 1
            MIRROR_NAME="Custom"
            ;;
    esac
}

# --- Step 4: Disk Selection ---
select_disk() {
    # Get disk list (exclude loop, ram, sr0)
    DISK_LIST=""
    DISK_NAMES=()
    DISK_SIZES=()
    DISK_MODELS=()
    DISK_COUNT=0
    
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        model=$(echo "$line" | cut -d' ' -f3-)
        if [[ "$name" == nvme* ]] || [[ "$name" == sd* ]] || [[ "$name" == vd* ]]; then
            DISK_NAMES+=("/dev/$name")
            DISK_SIZES+=("$size")
            DISK_MODELS+=("$model")
            DISK_COUNT=$((DISK_COUNT + 1))
        fi
    done < <(lsblk -d -o NAME,SIZE,MODEL -n 2>/dev/null | grep -v 'loop\|sr\|ram')
    
    if [ $DISK_COUNT -eq 0 ]; then
        die "No disks found! Please attach a disk and try again."
    fi
    
    # Build dialog menu
    MENU_ITEMS=()
    for i in $(seq 0 $((DISK_COUNT - 1))); do
        MENU_ITEMS+=("${DISK_NAMES[$i]}" "${DISK_SIZES[$i]} - ${DISK_MODELS[$i]}")
    done
    
    DISK=$(dialog --title "Disk Selection" \
        --menu "Select the disk to install ComplementaryOS to.\n\n\Z1WARNING: All data on this disk will be erased!\Zn" \
        $((10 + DISK_COUNT)) 65 $DISK_COUNT \
        "${MENU_ITEMS[@]}" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1
    
    log "Selected disk: $DISK"
}

# --- Step 5: Partition Scheme ---
choose_partition() {
    PARTITION_SCHEME=$(dialog --title "Partitioning" \
        --menu "Choose partitioning method:" 12 60 3 \
        "auto" "Use entire disk (automatic, recommended)" \
        "manual" "Manual partitioning with fdisk" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1
    
    if [ "$PARTITION_SCHEME" = "manual" ]; then
        dialog --title "Manual Partitioning" \
            --msgbox "Opening fdisk for manual partitioning.\n\n\
Create the following partitions:\n\
• /boot/efi (UEFI only): 512MB, type EFI System\n\
• /boot: 1GB, type Linux\n\
• / (root): rest of disk, type Linux\n\n\
When done, note your partition names (e.g., /dev/sda1, /dev/sda2)." 14 60
        clear
        fdisk "$DISK"
        dialog --title "Partitions" \
            --msgbox "Partitioning complete. Verify below:\n\n$(lsblk "$DISK" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null)" 14 60
    fi
}

# --- Step 6: User Account ---
create_user() {
    # Hostname
    HOSTNAME=$(dialog --title "Hostname" \
        --inputbox "Enter the system hostname:" 8 50 "$HOSTNAME" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1
    
    # Username
    USERNAME=$(dialog --title "User Account" \
        --inputbox "Enter your username:" 8 50 "$USERNAME" \
        3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return 1
    
    # Password
    while true; do
        USER_PASSWORD=$(dialog --title "User Password" \
            --insecure --passwordbox "Enter password for ${USERNAME}:\n\n(Password must be at least 6 characters)" 10 60 \
            3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && return 1
        
        CONFIRM_PASSWORD=$(dialog --title "Confirm Password" \
            --insecure --passwordbox "Confirm password:" 8 50 \
            3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && return 1
        
        if [ "$USER_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
            dialog --title "Error" --msgbox "Passwords do not match. Please try again." 6 50
        elif [ ${#USER_PASSWORD} -lt 6 ]; then
            dialog --title "Error" --msgbox "Password must be at least 6 characters." 6 50
        else
            break
        fi
    done
    
    # Root password (same as user for simplicity)
    dialog --title "Root Password" \
        --msgbox "Root password will be set to the same as ${USERNAME}." 6 55
}

# --- Step 7: SSH Configuration ---
configure_ssh() {
    ENABLE_SSH=$(dialog --title "SSH Server" \
        --yesno "Install and enable SSH server?" 6 45 \
        3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
        ENABLE_SSH="yes"
        SSH_PORT=$(dialog --title "SSH Port" \
            --inputbox "SSH port:" 8 40 "22" \
            3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && SSH_PORT="22"
    else
        ENABLE_SSH="no"
    fi
}

# --- Step 8: Summary ---
show_summary() {
    # Detect boot mode
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS/Legacy"
    fi
    
    SUMMARY="\Zb\Z3Installation Summary\Zn\n\n"
    SUMMARY+="Disk:        \Zb${DISK}\Zn\n"
    SUMMARY+="Boot Mode:   \Zb${BOOT_MODE}\Zn\n"
    SUMMARY+="Partition:   \Zb${PARTITION_SCHEME}\Zn\n"
    SUMMARY+="Mirror:      \Zb${MIRROR_NAME}\Zn\n"
    SUMMARY+="Hostname:    \Zb${HOSTNAME}\Zn\n"
    SUMMARY+="Username:    \Zb${USERNAME}\Zn\n"
    SUMMARY+="SSH:         \Zb${ENABLE_SSH}\Zn (port ${SSH_PORT})\n"
    SUMMARY+="Timezone:    \Zb${TIMEZONE}\Zn\n"
    SUMMARY+="Keyboard:    \Zb${KEYBOARD}\Zn\n\n"
    SUMMARY+="\Z1WARNING: All data on ${DISK} will be erased!\Zn"
    
    dialog --title "Confirm Installation" \
        --yesno "$SUMMARY" 20 65
    return $?
}

# --- Step 9: Partition and Format ---
do_partition() {
    log "Starting partitioning on $DISK..."
    
    # Wipe the disk
    dd if=/dev/zero of="$DISK" bs=1M count=10 2>/dev/null || true
    wipefs -a "$DISK" 2>/dev/null || true
    sync
    
    if [ -d /sys/firmware/efi ]; then
        # UEFI: GPT partition table
        log "Creating GPT partition table..."
        parted -s "$DISK" mklabel gpt 2>&1 | tee -a "$LOG_FILE"
        
        # EFI System Partition (512MB)
        log "Creating EFI System Partition..."
        parted -s "$DISK" mkpart primary fat32 1MiB 513MiB 2>&1 | tee -a "$LOG_FILE"
        parted -s "$DISK" set 1 esp on 2>&1 | tee -a "$LOG_FILE"
        PART_EFI="${DISK}1"
        if [[ "$DISK" == /dev/nvme* ]]; then
            PART_EFI="${DISK}p1"
        fi
        
        # Boot partition (1GB)
        log "Creating boot partition..."
        parted -s "$DISK" mkpart primary ext4 513MiB 1569MiB 2>&1 | tee -a "$LOG_FILE"
        PART_BOOT="${DISK}2"
        if [[ "$DISK" == /dev/nvme* ]]; then
            PART_BOOT="${DISK}p2"
        fi
        
        # Root partition (rest)
        log "Creating root partition..."
        parted -s "$DISK" mkpart primary ext4 1569MiB 100% 2>&1 | tee -a "$LOG_FILE"
        PART_ROOT="${DISK}3"
        if [[ "$DISK" == /dev/nvme* ]]; then
            PART_ROOT="${DISK}p3"
        fi
        
        # Format partitions
        log "Formatting partitions..."
        mkfs.vfat -F 32 -n "EFI" "$PART_EFI" 2>&1 | tee -a "$LOG_FILE"
        mkfs.ext4 -F -L "boot" "$PART_BOOT" 2>&1 | tee -a "$LOG_FILE"
        mkfs.ext4 -F -L "root" "$PART_ROOT" 2>&1 | tee -a "$LOG_FILE"
    else
        # BIOS: MBR partition table
        log "Creating MBR partition table..."
        parted -s "$DISK" mklabel msdos 2>&1 | tee -a "$LOG_FILE"
        
        # Boot partition (1GB)
        log "Creating boot partition..."
        parted -s "$DISK" mkpart primary ext4 1MiB 1025MiB 2>&1 | tee -a "$LOG_FILE"
        parted -s "$DISK" set 1 boot on 2>&1 | tee -a "$LOG_FILE"
        PART_BOOT="${DISK}1"
        if [[ "$DISK" == /dev/nvme* ]]; then
            PART_BOOT="${DISK}p1"
        fi
        
        # Root partition (rest)
        log "Creating root partition..."
        parted -s "$DISK" mkpart primary ext4 1025MiB 100% 2>&1 | tee -a "$LOG_FILE"
        PART_ROOT="${DISK}2"
        if [[ "$DISK" == /dev/nvme* ]]; then
            PART_ROOT="${DISK}p2"
        fi
        
        # Format
        log "Formatting partitions..."
        mkfs.ext4 -F -L "boot" "$PART_BOOT" 2>&1 | tee -a "$LOG_FILE"
        mkfs.ext4 -F -L "root" "$PART_ROOT" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Wait for partitions to settle
    sleep 2
    sync
    
    log "Partitioning complete"
    echo "$PART_ROOT" > /tmp/cos-part-root.txt
    echo "$PART_BOOT" > /tmp/cos-part-boot.txt
    if [ -d /sys/firmware/efi ]; then
        echo "$PART_EFI" > /tmp/cos-part-efi.txt
    fi
}

# --- Step 10: Extract and Configure ---
do_install() {
    PART_ROOT=$(cat /tmp/cos-part-root.txt 2>/dev/null)
    PART_BOOT=$(cat /tmp/cos-part-boot.txt 2>/dev/null)
    PART_EFI=""
    if [ -f /tmp/cos-part-efi.txt ]; then
        PART_EFI=$(cat /tmp/cos-part-efi.txt)
    fi
    
    (
        echo "XXX"
        echo "10"
        echo "Mounting partitions..."
        echo "XXX"
        sleep 1
        
        # Mount root
        mkdir -p /mnt/target
        mount "$PART_ROOT" /mnt/target
        
        # Mount boot
        mkdir -p /mnt/target/boot
        mount "$PART_BOOT" /mnt/target/boot
        
        if [ -n "$PART_EFI" ]; then
            mkdir -p /mnt/target/boot/efi
            mount "$PART_EFI" /mnt/target/boot/efi
        fi
        
        echo "XXX"
        echo "20"
        echo "Extracting rootfs..."
        echo "XXX"
        
        # Find and extract rootfs
        ROOTFS_ARCHIVE=""
        for src in /run/rootfs/base/rootfs.tar.zst /mnt/cdrom/rootfs.tar.zst /media/cdrom/rootfs.tar.zst \
            /mnt/rootfs.tar.zst /cdrom/rootfs.tar.zst /run/rootfs.tar.zst; do
            if [ -f "$src" ]; then
                ROOTFS_ARCHIVE="$src"
                break
            fi
        done
        
        if [ -z "$ROOTFS_ARCHIVE" ]; then
            # Try to find by mount
            ROOTFS_ARCHIVE=$(find / -maxdepth 3 -name "rootfs.tar.zst" 2>/dev/null | head -1)
        fi
        
        if [ -z "$ROOTFS_ARCHIVE" ]; then
            die "Cannot find rootfs.tar.zst. Make sure the ISO is mounted."
        fi
        
        log "Extracting $ROOTFS_ARCHIVE..."
        zstd -dc "$ROOTFS_ARCHIVE" | tar -xf - -C /mnt/target 2>&1 | tee -a "$LOG_FILE"
        
        echo "XXX"
        echo "50"
        echo "Configuring system..."
        echo "XXX"
        
        # Mount chroot filesystems
        mount --bind /proc /mnt/target/proc
        mount --bind /sys /mnt/target/sys
        mount --bind /dev /mnt/target/dev
        mount --bind /dev/pts /mnt/target/dev/pts
        cp -L /etc/resolv.conf /mnt/target/etc/resolv.conf 2>/dev/null || true
        
        # Configure fstab
        cat > /mnt/target/etc/fstab << FSTAB
# /etc/fstab - ComplementaryOS
$(blkid "$PART_ROOT" -s UUID -o value | awk -v m="/" '{printf "UUID=%s %s ext4 defaults,noatime 0 1\n", $1, m}')
$(blkid "$PART_BOOT" -s UUID -o value | awk -v m="/boot" '{printf "UUID=%s %s ext4 defaults,noatime 0 2\n", $1, m}')
FSTAB
        if [ -n "$PART_EFI" ]; then
            blkid "$PART_EFI" -s UUID -o value | awk '{printf "UUID=%s /boot/efi vfat defaults 0 2\n", $1}' >> /mnt/target/etc/fstab
        fi
        echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /mnt/target/etc/fstab
        
        echo "XXX"
        echo "60"
        echo "Setting up user accounts..."
        echo "XXX"
        
        # Configure hostname
        echo "$HOSTNAME" > /mnt/target/etc/hostname
        cat > /mnt/target/etc/hosts << HOSTEOF
127.0.0.1 localhost
127.0.1.1 ${HOSTNAME}
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
HOSTEOF
        
        # Set passwords (use chroot)
        chroot /mnt/target /bin/bash << CHROOTCFG
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8

# Create user if not exists
if ! id "${USERNAME}" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,staff,users "${USERNAME}"
fi

# Set passwords
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "root:${USER_PASSWORD}" | chpasswd

# Configure sudo - REQUIRE password (for 落盘 versions)
rm -f /etc/sudoers.d/99-${USERNAME}
cat > /etc/sudoers.d/99-${USERNAME} << SUDOEOF
# ComplementaryOS落盘版 - sudo requires password
${USERNAME} ALL=(ALL:ALL) ALL
SUDOEOF
chmod 440 /etc/sudoers.d/99-${USERNAME}

# Set timezone
echo "${TIMEZONE}" > /etc/timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

# Set locale
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen 2>/dev/null || true
echo 'LANG=en_US.UTF-8' > /etc/default/locale

# Configure keyboard
cat > /etc/default/keyboard << KEYBEOF
XKBMODEL="pc105"
XKBLAYOUT="${KEYBOARD}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KEYBEOF

# Configure apt sources
cat > /etc/apt/sources.list << APTEOF
deb ${MIRROR} bookworm main contrib non-free non-free-firmware
deb ${MIRROR} bookworm-updates main contrib non-free non-free-firmware
deb ${MIRROR_SECURITY} bookworm-security main contrib non-free non-free-firmware
APTEOF

# Configure SSH
if [ "${ENABLE_SSH}" = "yes" ]; then
    mkdir -p /run/sshd
    cat >> /etc/ssh/sshd_config << SSHEOF
PermitRootLogin yes
PasswordAuthentication yes
Port ${SSH_PORT}
UseDNS no
SSHEOF
    systemctl enable ssh 2>/dev/null || true
fi

# Enable essential services
systemctl enable systemd-resolved 2>/dev/null || true
systemctl enable haveged 2>/dev/null || true
systemctl enable cron 2>/dev/null || true
systemctl enable systemd-networkd 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true

# Generate machine-id
rm -f /etc/machine-id
dbus-uuidgen --ensure=/etc/machine-id 2>/dev/null || true

# Set default target to multi-user
systemctl set-default multi-user.target 2>/dev/null || true
CHROOTCFG

        echo "XXX"
        echo="80"
        echo "Installing bootloader..."
        echo "XXX"
        
        # Install GRUB
        if [ -d /sys/firmware/efi ]; then
            # UEFI
            chroot /mnt/target /bin/bash << GRUBUEFI
apt-get install -y grub-efi-amd64 2>&1 | tail -3
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ComplementaryOS 2>&1
update-grub 2>&1
GRUBUEFI
        else
            # BIOS
            chroot /mnt/target /bin/bash << GRUBBIOS
apt-get install -y grub-pc 2>&1 | tail -3
grub-install --target=i386-pc "${DISK}" 2>&1
update-grub 2>&1
GRUBBIOS
        fi
        
        echo "XXX"
        echo="95"
        echo "Cleaning up..."
        echo "XXX"
        
        # Clean up
        rm -f /mnt/target/etc/resolv.conf
        rm -rf /mnt/target/var/cache/apt 2>/dev/null || true
        rm -rf /mnt/target/var/lib/apt/lists 2>/dev/null || true
        rm -f /mnt/target/root/.bash_history 2>/dev/null || true
        
        # Create ComplementaryOS release file
        cat > /mnt/target/etc/os-release << OSREOF
PRETTY_NAME="ComplementaryOS ${VERSION}"
NAME="ComplementaryOS"
VERSION_ID="${VERSION}"
VERSION="${VERSION}"
ID=complementaryos
ID_LIKE=debian
HOME_URL="https://complementaryos.org"
OSREOF
        
        echo "XXX"
        echo "100"
        echo "Installation complete!"
        echo "XXX"
    ) | dialog --title "Installing ComplementaryOS" \
        --gauge "Preparing..." 8 60 0
    
    # Check if installation succeeded
    if [ ! -f /mnt/target/etc/os-release ]; then
        die "Installation failed! Target system not found."
    fi
    
    log "Installation completed successfully"
}

# --- Step 11: Finish ---
finish() {
    cleanup
    
    dialog --title "Installation Complete" \
        --msgbox "\Zb\Z2ComplementaryOS ${VERSION} has been installed successfully!\Zn\n\n\
Disk:        ${DISK}\n\
Hostname:    ${HOSTNAME}\n\
Username:    ${USERNAME}\n\
SSH:         ${ENABLE_SSH}\n\n\
\ZbRoot password is the same as ${USERNAME}'s password.\Zn\n\
\ZbSudo requires password verification.\Zn\n\n\
Remove the installation media and reboot." 18 60
    
    dialog --title "Reboot" \
        --yesno "Reboot now?" 6 40
    if [ $? -eq 0 ]; then
        reboot
    fi
}

# --- Main ---
main() {
    # Check root
    if [ "$(id -u)" != "0" ]; then
        echo "This installer must be run as root."
        exit 1
    fi
    
    # Check for dialog
    if ! which dialog >/dev/null 2>&1; then
        echo "dialog is required. Install it with: apt-get install dialog"
        exit 1
    fi
    
    # Initialize log
    rm -f "$LOG_FILE"
    log "ComplementaryOS Installer v${VERSION} started"
    
    # Run installation steps
    welcome || exit 1
    configure_locale || exit 1
    configure_mirror || exit 1
    select_disk || exit 1
    choose_partition || exit 1
    create_user || exit 1
    configure_ssh || exit 1
    show_summary || exit 1
    
    # Confirm again
    dialog --title "Final Warning" \
        --yesno "\Z1ALL DATA ON ${DISK} WILL BE ERASED!\Zn\n\nAre you REALLY sure you want to continue?" 8 50
    [ $? -ne 0 ] && exit 1
    
    # Install
    do_partition
    do_install
    finish
    
    log "Installer finished"
}

# Trap for cleanup
trap cleanup EXIT

# Run main
main "$@"
#!/bin/bash
# ==============================================================
# ComplementaryOS Text Installer
# Simple Q&A-style installer using read prompts
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
PARTITION_SCHEME="auto"
MIRROR="https://mirrors.ustc.edu.cn/debian"
MIRROR_SECURITY="https://mirrors.ustc.edu.cn/debian-security"
MIRROR_NAME="USTC (China)"
ENABLE_SSH="yes"
SSH_PORT="22"
LOCALE="en_US.UTF-8"
KEYBOARD="us"
TIMEZONE="Asia/Shanghai"
INSTALL_DEV_APPS="no"

# --- Helper functions ---
log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

log_stdout() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
    echo "$*"
}

# Read a value with default
read_val() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local input

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
    else
        read -p "$prompt: " input
    fi

    if [ -z "$input" ] && [ -n "$default" ]; then
        input="$default"
    fi

    eval "$var_name=\"$input\""
}

# Read a password (hidden input)
read_password() {
    local prompt="$1"
    local var_name="$2"
    local input=""
    local char=""

    echo -n "$prompt: "
    stty -echo
    read input
    stty echo
    echo ""

    eval "$var_name=\"$input\""
}

cleanup() {
    for mp in /mnt/target /mnt/target/boot /mnt/target/boot/efi /mnt/target/proc /mnt/target/sys /mnt/target/dev /mnt/target/dev/pts; do
        umount -lf "$mp" 2>/dev/null || true
    done
    dmsetup remove_all 2>/dev/null || true
}

die() {
    echo ""
    echo "=========================================="
    echo " FATAL ERROR"
    echo "=========================================="
    echo "$1"
    echo "See ${LOG_FILE} for details."
    echo "=========================================="
    cleanup
    exit 1
}

# Check if running in a terminal
check_terminal() {
    if [ ! -t 0 ]; then
        # Try to open a terminal
        exec </dev/tty1 >/dev/tty1 2>/dev/tty1
    fi
}

# Clear screen
cls() {
    printf "\033c" 2>/dev/null || clear 2>/dev/null || echo ""
}

# Print a header
print_header() {
    cls
    echo "============================================"
    echo "  ComplementaryOS ${VERSION} Installer"
    echo "============================================"
    echo ""
}

# --- Step 1: Welcome ---
welcome() {
    print_header
    echo "Welcome to the ComplementaryOS Installer!"
    echo ""
    echo "This wizard will guide you through installing"
    echo "ComplementaryOS to your hard disk."
    echo ""
    echo "Features:"
    echo "  * Automatic partitioning"
    echo "  * Multiple mirror selection"
    echo "  * SSH server configuration"
    echo "  * UEFI and Legacy BIOS support"
    echo ""
    echo "NOTE: This will ERASE the selected disk."
    echo "Make sure you have backups!"
    echo ""
    echo -n "Press Enter to continue... "
    read dummy
    log "Welcome completed"
}

# --- Step 2: Keyboard / Locale ---
configure_locale() {
    print_header
    echo "--- Keyboard Layout ---"
    echo ""
    echo "Common options: us, gb, de, fr, jp, cn, br, it, es"
    read_val "Keyboard layout" "us" KEYBOARD

    echo ""
    echo "--- Time Zone ---"
    echo "Common options: Asia/Shanghai, Asia/Tokyo, America/New_York,"
    echo "                Europe/London, Europe/Berlin, UTC"
    read_val "Time zone" "Asia/Shanghai" TIMEZONE

    log "Locale: KEYBOARD=$KEYBOARD TIMEZONE=$TIMEZONE"
}

# --- Step 3: Mirror Selection ---
configure_mirror() {
    print_header
    echo "--- APT Mirror Selection ---"
    echo ""
    echo "1) USTC           - mirrors.ustc.edu.cn (China, recommended)"
    echo "2) Tsinghua       - mirrors.tuna.tsinghua.edu.cn (China)"
    echo "3) Aliyun         - mirrors.aliyun.com (China)"
    echo "4) Huawei         - mirrors.huaweicloud.com (China)"
    echo "5) 163            - mirrors.163.com (China)"
    echo "6) Debian Official - deb.debian.org (Worldwide)"
    echo "7) Custom         - Enter your own mirror URL"
    echo ""
    read_val "Choose mirror (1-7)" "1" MIRROR_CHOICE

    case "$MIRROR_CHOICE" in
        2|Tsinghua)
            MIRROR="https://mirrors.tuna.tsinghua.edu.cn/debian"
            MIRROR_SECURITY="https://mirrors.tuna.tsinghua.edu.cn/debian-security"
            MIRROR_NAME="Tsinghua (China)"
            ;;
        3|Aliyun)
            MIRROR="https://mirrors.aliyun.com/debian"
            MIRROR_SECURITY="https://mirrors.aliyun.com/debian-security"
            MIRROR_NAME="Aliyun (China)"
            ;;
        4|Huawei)
            MIRROR="https://mirrors.huaweicloud.com/debian"
            MIRROR_SECURITY="https://mirrors.huaweicloud.com/debian-security"
            MIRROR_NAME="Huawei (China)"
            ;;
        5|163)
            MIRROR="https://mirrors.163.com/debian"
            MIRROR_SECURITY="https://mirrors.163.com/debian-security"
            MIRROR_NAME="163 (China)"
            ;;
        6|Debian)
            MIRROR="https://deb.debian.org/debian"
            MIRROR_SECURITY="https://security.debian.org/debian-security"
            MIRROR_NAME="Official Debian"
            ;;
        7|Custom)
            read_val "Enter Debian mirror URL" "https://mirrors.ustc.edu.cn/debian" MIRROR
            read_val "Enter security mirror URL" "https://mirrors.ustc.edu.cn/debian-security" MIRROR_SECURITY
            MIRROR_NAME="Custom"
            ;;
        *)
            MIRROR="https://mirrors.ustc.edu.cn/debian"
            MIRROR_SECURITY="https://mirrors.ustc.edu.cn/debian-security"
            MIRROR_NAME="USTC (China)"
            ;;
    esac

    log "Mirror: $MIRROR_NAME ($MIRROR)"
}

# --- Step 4: Disk Selection ---
select_disk() {
    print_header
    echo "--- Disk Selection ---"
    echo ""
    echo "Available disks:"
    echo "----------------------------------------"
    lsblk -d -o NAME,SIZE,MODEL -n 2>/dev/null | grep -v 'loop\|sr\|ram' | while IFS= read -r line; do
        echo "  /dev/$line"
    done
    echo "----------------------------------------"
    echo ""
    echo "WARNING: All data on the selected disk will be erased!"
    echo ""

    # Get disk list
    DISK_LIST=""
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        if [[ "$name" == nvme* ]] || [[ "$name" == sd* ]] || [[ "$name" == vd* ]]; then
            if [ -z "$DISK_LIST" ]; then
                DISK_LIST="/dev/$name"
            else
                DISK_LIST="$DISK_LIST /dev/$name"
            fi
        fi
    done < <(lsblk -d -o NAME -n 2>/dev/null | grep -v 'loop\|sr\|ram')

    if [ -z "$DISK_LIST" ]; then
        die "No disks found! Please attach a disk and try again."
    fi

    read_val "Install to disk" "$(echo $DISK_LIST | awk '{print $1}')" DISK

    log "Selected disk: $DISK"
}

# --- Step 5: Partition Scheme ---
choose_partition() {
    print_header
    echo "--- Partitioning ---"
    echo ""
    echo "Automatic partitioning will create:"
    echo "  UEFI: /boot/efi (512MB) + /boot (1GB) + / (rest)"
    echo "  BIOS: /boot (1GB) + / (rest)"
    echo ""
    echo -n "Use automatic partitioning? [Y/n]: "
    read auto_part
    if [ "$auto_part" = "n" ] || [ "$auto_part" = "N" ]; then
        PARTITION_SCHEME="manual"
        echo ""
        echo "Opening fdisk for manual partitioning..."
        echo "Create the following partitions:"
        echo "  UEFI: 512MB EFI System + 1GB ext4 /boot + rest ext4 /"
        echo "  BIOS: 1GB ext4 /boot (bootable) + rest ext4 /"
        echo ""
        echo -n "Press Enter to start fdisk... "
        read dummy
        fdisk "$DISK"
        echo ""
        echo "Current partitions:"
        lsblk "$DISK" -o NAME,SIZE,TYPE,FSTYPE 2>/dev/null
        echo ""
        echo -n "Press Enter to continue... "
        read dummy
    else
        PARTITION_SCHEME="auto"
    fi

    log "Partition scheme: $PARTITION_SCHEME"
}

# --- Step 6: User Account ---
create_user() {
    print_header
    echo "--- User Account ---"
    echo ""
    read_val "Hostname" "complementaryos" HOSTNAME
    read_val "Username" "user" USERNAME

    while true; do
        echo ""
        read_password "Password for ${USERNAME}" USER_PASSWORD
        read_password "Confirm password" CONFIRM_PASSWORD

        if [ "$USER_PASSWORD" != "$CONFIRM_PASSWORD" ]; then
            echo ""
            echo "ERROR: Passwords do not match. Please try again."
        elif [ ${#USER_PASSWORD} -lt 6 ]; then
            echo ""
            echo "ERROR: Password must be at least 6 characters."
        else
            break
        fi
    done

    echo ""
    echo "Root password will be set to the same as ${USERNAME}'s password."
    sleep 1

    log "User: $USERNAME, Hostname: $HOSTNAME"
}

# --- Step 7: SSH Configuration ---
configure_ssh() {
    print_header
    echo "--- SSH Server ---"
    echo ""
    echo -n "Install and enable SSH server? [Y/n]: "
    read ssh_choice
    if [ "$ssh_choice" = "n" ] || [ "$ssh_choice" = "N" ]; then
        ENABLE_SSH="no"
    else
        ENABLE_SSH="yes"
        read_val "SSH port" "22" SSH_PORT
    fi

    log "SSH: $ENABLE_SSH (port $SSH_PORT)"
}

# --- Step 8: Summary ---
show_summary() {
    print_header
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS/Legacy"
    fi

    echo "--- Installation Summary ---"
    echo ""
    echo "  Disk:        $DISK"
    echo "  Boot Mode:   $BOOT_MODE"
    echo "  Partition:   $PARTITION_SCHEME"
    echo "  Mirror:      $MIRROR_NAME"
    echo "  Hostname:    $HOSTNAME"
    echo "  Username:    $USERNAME"
    echo "  SSH:         $ENABLE_SSH (port $SSH_PORT)"
    echo "  Timezone:    $TIMEZONE"
    echo "  Keyboard:    $KEYBOARD"
    echo ""
    echo "WARNING: All data on $DISK will be erased!"
    echo ""
    echo -n "Proceed with installation? [y/N]: "
    read confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return 1
    return 0
}

# --- Step 9: Partition and Format ---
do_partition() {
    log "Starting partitioning on $DISK..."

    echo "Partitioning disk..."
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
        echo "  Formatting EFI partition..."
        mkfs.vfat -F 32 -n "EFI" "$PART_EFI" 2>&1 | tee -a "$LOG_FILE"
        echo "  Formatting boot partition..."
        mkfs.ext4 -F -L "boot" "$PART_BOOT" 2>&1 | tee -a "$LOG_FILE"
        echo "  Formatting root partition..."
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
        echo "  Formatting boot partition..."
        mkfs.ext4 -F -L "boot" "$PART_BOOT" 2>&1 | tee -a "$LOG_FILE"
        echo "  Formatting root partition..."
        mkfs.ext4 -F -L "root" "$PART_ROOT" 2>&1 | tee -a "$LOG_FILE"
    fi

    sleep 2
    sync

    log "Partitioning complete"
    echo "$PART_ROOT" > /tmp/cos-part-root.txt
    echo "$PART_BOOT" > /tmp/cos-part-boot.txt
    if [ -d /sys/firmware/efi ]; then
        echo "$PART_EFI" > /tmp/cos-part-efi.txt
    fi

    echo "  Partitioning done."
}

# --- Step 10: Extract and Configure ---
do_install() {
    PART_ROOT=$(cat /tmp/cos-part-root.txt 2>/dev/null)
    PART_BOOT=$(cat /tmp/cos-part-boot.txt 2>/dev/null)
    PART_EFI=""
    if [ -f /tmp/cos-part-efi.txt ]; then
        PART_EFI=$(cat /tmp/cos-part-efi.txt)
    fi

    echo ""
    echo "--- Installing ComplementaryOS ---"
    echo ""

    echo "  [10%] Mounting partitions..."
    log "Mounting partitions..."

    mkdir -p /mnt/target
    mount "$PART_ROOT" /mnt/target

    mkdir -p /mnt/target/boot
    mount "$PART_BOOT" /mnt/target/boot

    if [ -n "$PART_EFI" ]; then
        mkdir -p /mnt/target/boot/efi
        mount "$PART_EFI" /mnt/target/boot/efi
    fi

    echo "  [20%] Extracting rootfs..."
    log "Extracting rootfs..."

    ROOTFS_ARCHIVE=""
    for src in /run/rootfs/base/rootfs.tar.zst /mnt/cdrom/rootfs.tar.zst /media/cdrom/rootfs.tar.zst \
        /mnt/rootfs.tar.zst /cdrom/rootfs.tar.zst /run/rootfs.tar.zst; do
        if [ -f "$src" ]; then
            ROOTFS_ARCHIVE="$src"
            break
        fi
    done

    if [ -z "$ROOTFS_ARCHIVE" ]; then
        ROOTFS_ARCHIVE=$(find / -maxdepth 3 -name "rootfs.tar.zst" 2>/dev/null | head -1)
    fi

    if [ -z "$ROOTFS_ARCHIVE" ]; then
        die "Cannot find rootfs.tar.zst. Make sure the ISO is mounted."
    fi

    log "Extracting $ROOTFS_ARCHIVE..."
    zstd -dc "$ROOTFS_ARCHIVE" | tar -xf - -C /mnt/target 2>&1 | tee -a "$LOG_FILE"

    echo "  [50%] Configuring system..."
    log "Configuring system..."

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

    echo "  [60%] Setting up user accounts..."
    log "Setting up user accounts..."

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

if ! id "${USERNAME}" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,adm,staff,users "${USERNAME}"
fi

echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
echo "root:${USER_PASSWORD}" | chpasswd

rm -f /etc/sudoers.d/99-${USERNAME}
cat > /etc/sudoers.d/99-${USERNAME} << SUDOEOF
${USERNAME} ALL=(ALL:ALL) ALL
SUDOEOF
chmod 440 /etc/sudoers.d/99-${USERNAME}

echo "${TIMEZONE}" > /etc/timezone
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen 2>/dev/null || true
echo 'LANG=en_US.UTF-8' > /etc/default/locale

cat > /etc/default/keyboard << KEYBEOF
XKBMODEL="pc105"
XKBLAYOUT="${KEYBOARD}"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KEYBEOF

cat > /etc/apt/sources.list << APTEOF
deb ${MIRROR} bookworm main contrib non-free non-free-firmware
deb ${MIRROR} bookworm-updates main contrib non-free non-free-firmware
deb ${MIRROR_SECURITY} bookworm-security main contrib non-free non-free-firmware
APTEOF

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

systemctl enable systemd-resolved 2>/dev/null || true
systemctl enable haveged 2>/dev/null || true
systemctl enable cron 2>/dev/null || true
systemctl enable systemd-networkd 2>/dev/null || true
systemctl disable NetworkManager 2>/dev/null || true

rm -f /etc/machine-id
dbus-uuidgen --ensure=/etc/machine-id 2>/dev/null || true

systemctl set-default multi-user.target 2>/dev/null || true
CHROOTCFG

    echo "  [80%] Installing bootloader..."
    log "Installing bootloader..."

    if [ -d /sys/firmware/efi ]; then
        chroot /mnt/target /bin/bash << GRUBUEFI
apt-get install -y grub-efi-amd64 2>&1 | tail -3
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ComplementaryOS 2>&1
update-grub 2>&1
GRUBUEFI
    else
        chroot /mnt/target /bin/bash << GRUBBIOS
apt-get install -y grub-pc 2>&1 | tail -3
grub-install --target=i386-pc "${DISK}" 2>&1
update-grub 2>&1
GRUBBIOS
    fi

    echo "  [95%] Cleaning up..."
    log "Cleaning up..."

    rm -f /mnt/target/etc/resolv.conf
    rm -rf /mnt/target/var/cache/apt 2>/dev/null || true
    rm -rf /mnt/target/var/lib/apt 2>/dev/null || true
    rm -f /mnt/target/root/.bash_history 2>/dev/null || true

    cat > /mnt/target/etc/os-release << OSREOF
PRETTY_NAME="ComplementaryOS ${VERSION}"
NAME="ComplementaryOS"
VERSION_ID="${VERSION}"
VERSION="${VERSION}"
ID=complementaryos
ID_LIKE=debian
HOME_URL="https://complementaryos.org"
OSREOF

    echo "  [100%] Installation complete!"

    if [ ! -f /mnt/target/etc/os-release ]; then
        die "Installation failed! Target system not found."
    fi

    log "Installation completed successfully"
}

# --- Step 11: Finish ---
finish() {
    cleanup

    echo ""
    echo "============================================"
    echo "  Installation Complete!"
    echo "============================================"
    echo ""
    echo "  Disk:        $DISK"
    echo "  Hostname:    $HOSTNAME"
    echo "  Username:    $USERNAME"
    echo "  SSH:         $ENABLE_SSH"
    echo ""
    echo "  Root password is the same as ${USERNAME}'s password."
    echo "  Sudo requires password verification."
    echo ""
    echo "  Remove the installation media and reboot."
    echo ""

    echo -n "Reboot now? [y/N]: "
    read reboot_choice
    if [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ]; then
        echo "Rebooting..."
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

    # Ensure we have a terminal
    check_terminal

    # Initialize log
    rm -f "$LOG_FILE"
    log "ComplementaryOS Installer v${VERSION} started"
    log "TERM=$TERM"

    # Run installation steps
    welcome
    configure_locale
    configure_mirror
    select_disk
    choose_partition
    create_user
    configure_ssh
    show_summary || exit 1

    # Final confirmation
    echo ""
    echo "============================================"
    echo "  FINAL WARNING"
    echo "============================================"
    echo "  ALL DATA ON $DISK WILL BE ERASED!"
    echo ""
    echo -n "Are you REALLY sure you want to continue? [y/N]: "
    read final_confirm
    [ "$final_confirm" != "y" ] && [ "$final_confirm" != "Y" ] && exit 1

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
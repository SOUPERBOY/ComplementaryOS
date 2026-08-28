# ComplementaryOS

基于 Debian 的轻量级、可定制 Linux 发行版，使用自定义 Linux 7.1.3 内核构建。支持 RAMOS（内存运行）和持久化（磁盘安装）两种运行模式。

## 特性

- **自定义内核** — 基于 Linux 7.1.3，针对桌面和服务器使用优化配置
- **双启动模式**：
  - **RAMOS** — 通过 squashfs + overlayfs 完全在内存中运行，无需磁盘
  - **持久化安装** — 安装到磁盘，完整 Debian Bookworm 基础系统
- **TUI 安装器** — Ubuntu Server 风格的文本安装向导（基于 dialog）
- **桌面环境** — GUI 版本集成 KDE Plasma + Wayland
- **优化启动** — 极简 initramfs（1.2MB），zstd 快速 squashfs 解压
- **可读写根目录** — RAMOS 模式下通过 overlayfs 提供可写根文件系统

## 版本

| 版本 | 类型 | 目标 | 大小 |
|------|------|------|------|
| `complementaryos-release2.0.0-ramos-cli.iso` | RAMOS | 命令行（多用户） | ~437 MB |
| `complementaryos-release2.0.0-ramos-gui.iso` | RAMOS | 桌面（图形界面） | ~437 MB |
| `complementaryos-release2.0.0.iso` | 持久化安装 | 命令行 + 安装器 | ~815 MB |
| `complementaryos-release2.0.0-gui.iso` | 持久化安装 | 桌面 + 安装器 | ~815 MB |

## 构建前提

从源码构建 ComplementaryOS 需要：

- **Debian/Ubuntu WSL 或原生 Linux 环境**
- **自定义 Linux 7.1.3 内核**，编译于 `/home/user/linux-7.1.3/`，需包含：
  - `CONFIG_SQUASHFS=y` 和 `CONFIG_SQUASHFS_ZSTD=y`
  - `CONFIG_OVERLAY_FS=y`
  - AHCI / NVMe / virtio 驱动
- `debootstrap`、`squashfs-tools`、`grub-common`、`grub-pc-bin`、`grub-efi-amd64-bin`、`xorriso`
- `busybox`（initramfs 使用的静态二进制）
- `zstd`（压缩工具）

## 快速开始

### 从源码构建

```bash
# 克隆仓库
git clone <repo-url> complementaryos
cd complementaryos

# 运行构建脚本
# 注意：需要预先编译好的内核 /home/user/linux-7.1.3/
# 以及 Debian 根文件系统 /home/ramos-build/rootfs/
sudo bash optimize-build.sh
```

脚本会在 `output/` 目录下生成四个 ISO 镜像文件。

### 使用 QEMU 测试

```bash
# RAMOS 命令行版
qemu-system-x86_64 -m 2G -cpu host -smp 2 -enable-kvm \
  -cdrom output/complementaryos-release2.0.0-ramos-cli.iso \
  -nographic -serial mon:stdio

# RAMOS 桌面版
qemu-system-x86_64 -m 2G -cpu host -smp 2 -enable-kvm \
  -cdrom output/complementaryos-release2.0.0-ramos-gui.iso \
  -vga virtio -display gtk

# 持久化安装器（命令行版）
qemu-system-x86_64 -m 2G -cpu host -smp 2 -enable-kvm \
  -cdrom output/complementaryos-release2.0.0.iso \
  -drive file=test-disk.qcow2,format=qcow2,if=virtio \
  -nographic -serial mon:stdio
```

### 使用 VMware 测试

1. 创建新虚拟机（Linux > Debian 12 x64）
2. 将 ISO 附加到 CD/DVD 驱动器
3. 从 ISO 启动
4. RAMOS 版本：直接启动到桌面或命令行
5. 持久化安装版本：安装器自动在 VGA 控制台（tty1）启动

### 默认登录信息（RAMOS）

| 字段 | 值 |
|------|-----|
| 用户名 | `user` |
| 密码 | `complementary` |
| 主机名 | `complementaryos` |

> **注意：** 持久化安装模式下，安装过程中会提示设置密码。安装后的系统每次使用 sudo 都需要验证密码。

## 项目结构

```
.
├── optimize-build.sh          # 主构建脚本 (v2.0.0)
├── cos-installer-tui.sh       # 持久化安装的 TUI 安装器
├── install-modules.sh         # 内核模块安装辅助脚本
├── update-modules.sh          # 内核模块更新辅助脚本
├── output/                    # 构建好的 ISO 镜像
│   ├── complementaryos-release2.0.0-ramos-cli.iso
│   ├── complementaryos-release2.0.0-ramos-gui.iso
│   ├── complementaryos-release2.0.0.iso
│   └── complementaryos-release2.0.0-gui.iso
├── .gitignore
├── README.md
└── README.zh-CN.md
```

## 构建详情

### 构建脚本：`optimize-build.sh`

构建过程包含六个步骤：

1. **裁剪根文件系统** — 移除不必要的包、库、内核模块、图标、字体和本地化数据
2. **优化 systemd** — 禁用非必需服务（plymouth、ModemManager、accounts-daemon 等）
3. **创建 rootfs.squashfs** — 将完整系统打包为 zstd 压缩的 squashfs 镜像
4. **创建 live.squashfs** — 构建仅包含安装器和 Python 运行时的最小化 live 环境
5. **构建 initramfs** — 使用 BusyBox 创建两个 initramfs 变体（RAMOS 和安装器）
6. **构建 ISO 镜像** — 使用 GRUB 引导生成四个 ISO 变体

### TUI 安装器：`cos-installer-tui.sh`

安装器提供分步安装向导：

1. 键盘和本地化配置
2. APT 软件源选择（中科大、清华、阿里云、华为云、163、Debian 官方或自定义）
3. 磁盘选择和分区（自动或手动 fdisk）
4. 用户账户创建（密码确认）
5. SSH 服务器配置
6. 安装摘要和确认
7. 分区、格式化和系统解压
8. 系统配置（fstab、主机名、GRUB 等）
9. 重启

## 许可证

本项目仅供教育和个人使用。Debian 基础系统遵循 Debian 自由软件指南（DFSG）。第三方软件包遵循其各自的许可证。
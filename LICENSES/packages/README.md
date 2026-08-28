# Debian Package License and Copyright Files

This directory contains collected Debian package copyright, license, README, changelog, and NEWS files from the WSL host system (Ubuntu) and the WSL rootfs.

## Structure

```
packages/
  README.md                - This file
  package-list.txt         - Full list of installed packages with versions
  licenses/                - Common license files from /usr/share/common-licenses/
  copyright/               - Package copyright files, one per package
  readme/                  - README files from package doc directories
  changelog/               - Changelog files from package doc directories
  news/                    - NEWS files from package doc directories
```

## Sources

### WSL Host System (Ubuntu)
- Source: `/usr/share/doc/` on the running Ubuntu WSL instance
- Installed packages: 1105
- Copyright files collected: 1104
- README files collected: 514
- Changelog files collected: 1142
- NEWS files collected: 278

### WSL Rootfs
- Source: `/home/ramos-build/rootfs/usr/share/doc/` on the rootfs
- Installed packages: 1525
- The rootfs is a minimal installation with doc files only for the `dialog` package
- Additional files collected from rootfs: 4 (dialog README, CHANGES, changelogs)

## Common Licenses

The following common license files are available in `licenses/`:

- Apache-2.0 (12K)
- Artistic (8.0K)
- BSD (4.0K)
- CC0-1.0 (8.0K)
- GFDL (0)
- GFDL-1.2 (20K)
- GFDL-1.3 (24K)
- GPL (0)
- GPL-1 (16K)
- GPL-2 (20K)
- GPL-3 (36K)
- LGPL (0)
- LGPL-2 (28K)
- LGPL-2.1 (28K)
- LGPL-3 (8.0K)
- MPL-1.1 (28K)
- MPL-2.0 (20K)

## Summary

| Directory | File Count | Total Size |
|-----------|-----------|------------|
| licenses | 17 | 332K |
| copyright | 1105 | 22M |
| readme | 515 | 2.9M |
| changelog | 1145 | 15M |
| news | 278 | 7.6M |
| package-list.txt | 1 | 176K |
| **Total** | | 48M |

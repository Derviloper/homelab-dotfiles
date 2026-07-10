# homelab-dotfiles

Minimal, headless NixOS configuration for a single homelab host, managed as a Nix
flake. Disks are declared with [disko](https://github.com/nix-community/disko),
user environment with [home-manager](https://github.com/nix-community/home-manager),
and remote updates run through [deploy-rs](https://github.com/serokell/deploy-rs).

## Overview

- **Host:** `homelab` — `x86_64-linux`, systemd-boot / EFI, ext4 root on a single disk (`/dev/sda`).
- **User:** `admin` (wheel, passwordless sudo, SSH key auth only). Root SSH login is disabled.
- **Shell:** zsh with powerlevel10k.
- **Services:** OpenSSH (port 22 only), fail2ban.

```
.
├── flake.nix                 # inputs + nixosConfigurations.homelab + deploy nodes
├── hosts/homelab/
│   ├── default.nix           # system config (users, ssh, nix, packages)
│   ├── disko.nix             # declarative disk layout (/dev/sda)
│   ├── hardware-configuration.nix
│   └── p10k.zsh              # prompt theme
└── home/admin/               # home-manager config for `admin`
```

## Prerequisites

- Nix with flakes enabled on the machine you run commands _from_ (the controller).
- The target's disk name. disko is configured for `/dev/sda` — verify with `lsblk`
  and edit [hosts/homelab/disko.nix](hosts/homelab/disko.nix) if the target differs.
- An SSH public key added to `admin` in
  [hosts/homelab/default.nix](hosts/homelab/default.nix)
  (`users.users.admin.openssh.authorizedKeys.keys`). Without it there is no way to
  log in after install — root SSH is disabled by design.

> ⚠️ The disko install steps **erase the target disk**. Make sure you have the
> right machine and device.

## 1. Physical install (NixOS live installer)

Boot the official NixOS installer ISO on the target, then:

```sh
# 1. Partition, format, and mount the disk from disko.nix
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- \
  --mode disko \
  --flake github:Derviloper/homelab-dotfiles#homelab

# 2. Install the system from the flake
sudo nixos-install --flake github:Derviloper/homelab-dotfiles#homelab

# 3. Set a root password when prompted, then reboot
sudo reboot
```

Set a root password when prompted, then `reboot`.

> **Different hardware?** `hardware-configuration.nix` is committed and specific to
> the original machine. If the target hardware differs, regenerate it before
> installing: `nixos-generate-config --no-filesystems --root /mnt` and replace
> [hosts/homelab/hardware-configuration.nix](hosts/homelab/hardware-configuration.nix).

## 2. Remote install (nixos-anywhere, over SSH)

Use this when the target is reachable over SSH as `root` — e.g. booted into the
NixOS live installer with a root password set (`passwd`), or any existing Linux.

From the controller (nixos-anywhere runs via `nix run`, no flake input needed):

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake github:Derviloper/homelab-dotfiles#homelab \
  --target-host homelab
```

nixos-anywhere kexecs into an installer, runs disko (**erasing `/dev/sda`**),
installs the system, and reboots. After reboot, log in as `admin` with your SSH
key — root SSH is disabled.

## 3. Updates (deploy-rs)

The flake defines a deploy node for `homelab` (connects as `admin`, activates via
passwordless sudo, with automatic rollback on failure). From a checkout of this
repo on the controller:

```sh
nix run github:serokell/deploy-rs -- .#homelab
# or, with deploy-rs installed:
deploy .#homelab
```

The node targets the hostname `homelab`, so it must resolve from the controller
(DNS, mDNS, or an `/etc/hosts` entry). Override the target per invocation if
needed:

```sh
deploy .#homelab --hostname <ip>
```

### Updating locally (on the host)

If you're on the machine itself:

```sh
sudo nixos-rebuild switch --flake .#homelab
```

## Maintenance

- Format Nix files: `nix fmt` (nixfmt).
- Validate the flake and deploy config: `nix flake check`.
- The nix store is garbage-collected weekly and auto-optimised (see
  [hosts/homelab/default.nix](hosts/homelab/default.nix)).

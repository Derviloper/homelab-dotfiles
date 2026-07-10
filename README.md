# homelab-dotfiles

Minimal, headless NixOS configuration for a single homelab host, managed as a Nix
flake. Disks are declared with [disko](https://github.com/nix-community/disko),
user environment with [home-manager](https://github.com/nix-community/home-manager),
and remote updates run through [deploy-rs](https://github.com/serokell/deploy-rs).

## Overview

- **Host:** `homelab` — `x86_64-linux`, systemd-boot / EFI, ext4 root on a single disk (`/dev/sda`).
- **User:** `admin` (wheel, passwordless sudo, SSH key auth only). Root SSH login is disabled.
- **Shell:** zsh with powerlevel10k.
- **Network:** DHCP on a `br0` bridge (over `enp2s0`) so VMs attach directly to the LAN.
- **Services:** OpenSSH (port 22 only), fail2ban, libvirt/KVM (hosts the Home Assistant OS VM).

```
.
├── flake.nix                 # inputs + nixosConfigurations.homelab + deploy nodes
├── hosts/homelab/
│   ├── default.nix           # host specifics (hostname, boot) + module imports
│   ├── disko.nix             # declarative disk layout (/dev/sda)
│   ├── haos-domain.xml       # reference dump of the imperative HAOS libvirt domain
│   └── hardware-configuration.nix
├── modules/                  # cross-cutting system config, one file per concern
│   ├── nix.nix               # nix daemon settings, gc, allowUnfree, trusted-users
│   ├── ssh.nix               # OpenSSH + fail2ban
│   ├── networking.nix        # br0 bridge, avahi (mDNS), firewall
│   ├── virtualisation.nix    # libvirt/KVM host for the HAOS VM
│   ├── users.nix             # admin user, sudo, home-manager
│   ├── shell.nix             # zsh, packages, prompt
│   ├── locale.nix            # timezone + locale
│   └── p10k.zsh              # prompt theme
└── home/admin/               # home-manager config for `admin`
```

## Prerequisites

- Nix with flakes enabled on the machine you run commands _from_ (the controller).
- The target's disk name. disko is configured for `/dev/sda` — verify with `lsblk`
  and edit [hosts/homelab/disko.nix](hosts/homelab/disko.nix) if the target differs.
- An SSH public key added to `admin` in
  [modules/users.nix](modules/users.nix)
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

## 4. Home Assistant OS VM

The host configuration already provides everything HAOS needs declaratively: a
`br0` LAN bridge over `enp2s0`
([modules/networking.nix](modules/networking.nix)) and `libvirtd` with `admin` in
the `libvirtd` group ([modules/virtualisation.nix](modules/virtualisation.nix)).
So on a freshly installed host these are in place after step 1/2 above — no extra
config needed.

> **Different wired NIC?** The bridge enslaves `enp2s0`. If your interface differs
> (check `ip link`), update `networking.bridges.br0.interfaces` in
> [modules/networking.nix](modules/networking.nix) before installing.

Only the **VM itself is imperative**: HAOS self-updates and continuously writes to
its own disk, so its qcow2 lives as mutable state in `/var/lib/libvirt/images`,
**not** in the Nix store. A reference dump of the domain is kept at
[hosts/homelab/haos-domain.xml](hosts/homelab/haos-domain.xml). Run the steps below
once, on the host, as `admin`.

### 4.1 Download the latest HAOS KVM image

```sh
workdir="$(mktemp -d -p "$HOME")"; cd "$workdir"

url="$(nix shell nixpkgs#curl nixpkgs#jq -c bash -c '
  curl -fsSL https://api.github.com/repos/home-assistant/operating-system/releases/latest |
  jq -r ".assets[] | select(.name | test(\"^haos_ova-.*[.]qcow2[.]xz$\")) | .browser_download_url" |
  head -n1')"

nix shell nixpkgs#curl       -c curl -fL "$url" -o haos.qcow2.xz
nix shell nixpkgs#xz         -c xz --decompress haos.qcow2.xz
nix shell nixpkgs#qemu-utils -c qemu-img resize haos.qcow2 64G

sudo install -d -m 0755 /var/lib/libvirt/images
sudo mv haos.qcow2 /var/lib/libvirt/images/haos.qcow2
sudo chown root:root /var/lib/libvirt/images/haos.qcow2
```

### 4.2 Create and autostart the VM

```sh
virt-install --connect qemu:///system \
  --name haos --description "Home Assistant OS" \
  --os-variant generic \
  --memory 12288 --vcpus 4 --cpu host-passthrough --machine q35 \
  --disk path=/var/lib/libvirt/images/haos.qcow2,format=qcow2,bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --network bridge=br0,model=virtio \
  --import --graphics none --boot uefi --noautoconsole

virsh --connect qemu:///system autostart haos
```

`--memory`/`--vcpus` are sized for this host (16 GiB / 4-core N150); adjust to
taste. Resize later without recreating the VM via `virsh setvcpus`/`setmem`
(`--config`) or `virsh edit haos`, then reboot the guest.

### 4.3 Reach Home Assistant

First boot takes a few minutes while HAOS prepares its partitions, then open
<http://homeassistant.local:8123> (or `http://<vm-ip>:8123`). Find the VM's IP
from its MAC:

```sh
virsh --connect qemu:///system domiflist haos   # note the MAC
ip neigh show dev br0                            # or check the router's DHCP leases
```

Create a DHCP reservation for that MAC in the router so the address is stable, and
use Home Assistant's own backup system with an off-machine copy — the qcow2 on the
same box is not disaster recovery.

### 4.4 USB radios (Zigbee / Z-Wave / Bluetooth)

Find the dongle's vendor:product IDs (`nix shell nixpkgs#usbutils -c lsusb`), then:

```sh
virsh --connect qemu:///system shutdown haos
virsh --connect qemu:///system edit haos     # add the <hostdev> below inside <devices>
virsh --connect qemu:///system start haos
```

```xml
<hostdev mode="subsystem" type="usb" managed="yes">
  <source><vendor id="0x1a86"/><product id="0x55d4"/></source>
</hostdev>
```

## Maintenance

- Format Nix files: `nix fmt` (nixfmt).
- Validate the flake and deploy config: `nix flake check`.
- The nix store is garbage-collected weekly and auto-optimised (see
  [modules/nix.nix](modules/nix.nix)).
- HAOS VM (on the host): `virsh --connect qemu:///system start|shutdown|reboot|console haos`,
  `virsh --connect qemu:///system list --all`, `journalctl -u libvirtd`.

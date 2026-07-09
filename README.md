# homelab-dotfiles

Minimal, headless [NixOS](https://nixos.org/) configuration for a single homelab host, built as a [Nix flake](https://nixos.wiki/wiki/Flakes). Disk layout is declared with [disko](https://github.com/nix-community/disko) and the user environment is managed with [home-manager](https://github.com/nix-community/home-manager).

## Layout

```
flake.nix                  # inputs, nixosConfigurations.homelab, nixfmt formatter
hosts/homelab/
  default.nix              # host system config (SSH, users, nix, packages, zsh)
  disko.nix                # declarative disk partitioning (/dev/nvme0n1)
  hardware-configuration.nix  # placeholder — regenerated on the target at install
  p10k.zsh                 # powerlevel10k prompt, exposed at /etc/p10k.zsh
home/admin/default.nix     # home-manager config for the `admin` user (git)
```

## What you get

- Pinned to `nixos-26.05`, with flakes and `nix-command` enabled.
- `systemd-boot` on EFI.
- Single `admin` user (in `wheel`, passwordless sudo), with `zsh` + powerlevel10k, autosuggestions and syntax highlighting.
- OpenSSH with root login disabled, `fail2ban`, and a firewall that only opens port 22.
- Weekly garbage collection (`--delete-older-than 14d`) and automatic store optimisation.
- Timezone `Europe/Berlin`, locale `en_US.UTF-8`.

## Installing

> **Before you start:** `disko` will **erase** the target disk. The layout in
> [`hosts/homelab/disko.nix`](hosts/homelab/disko.nix) is hardcoded to
> `/dev/nvme0n1` — confirm with `lsblk` that this is the right device (or edit
> the file) before running anything below.

### From the NixOS installer (physical access)

Boot the machine from the official NixOS ISO and run:

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

After reboot, log in as **root at the console** with the password you set
(`PermitRootLogin = "no"` only blocks root over SSH, not the local console).
The `admin` user ships without a password, so set one straight away:

```sh
passwd admin
```

This installs from the committed [`hardware-configuration.nix`](hosts/homelab/hardware-configuration.nix),
which is a generic placeholder — enough to boot most x86_64 UEFI machines, but
without this host's CPU microcode or special kernel modules. To capture the real
hardware, clone the repo locally after step 1 and generate the config before
installing:

```sh
# after disko has mounted everything under /mnt
git clone https://github.com/Derviloper/homelab-dotfiles /mnt/tmp/cfg
nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  > /mnt/tmp/cfg/hosts/homelab/hardware-configuration.nix
sudo nixos-install --flake /mnt/tmp/cfg#homelab
```

`--no-filesystems` is used because the filesystems are declared in `disko.nix`.
Commit the regenerated `hardware-configuration.nix` back to the repo afterwards.

### Remotely with nixos-anywhere (over SSH)

For an unattended install onto a machine reachable over SSH, use
[`nixos-anywhere`](https://github.com/nix-community/nixos-anywhere), which runs
`disko` and installs the flake in one step:

1. Boot the target into a NixOS installer / rescue environment reachable over SSH.
2. From a checkout of this repo, run:

   ```sh
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#homelab \
     --generate-hardware-config nixos-generate-config ./hosts/homelab/hardware-configuration.nix \
     root@<target-ip>
   ```

3. Commit the regenerated `hardware-configuration.nix`.

> Note: this flow needs a way to log in afterwards — the config currently sets
> no password or SSH key for `admin`, so add `users.users.admin.openssh.authorizedKeys.keys`
> (or a `hashedPassword`) before relying on remote access.

## Updating

After the initial install, rebuild from the host:

```sh
sudo nixos-rebuild switch --flake .#homelab
```

Bump pinned inputs with:

```sh
nix flake update
```

## Formatting

```sh
nix fmt
```

Formats the tree with [`nixfmt`](https://github.com/NixOS/nixfmt).

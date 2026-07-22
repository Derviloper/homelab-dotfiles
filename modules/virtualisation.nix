{ pkgs, lib, ... }:
let
  # USB dongles passed through to the imperatively-managed `haos` libvirt domain,
  # matched by VID:PID (see hosts/homelab/haos-domain.xml). When one of these
  # resets and re-enumerates while the VM is running, libvirt does NOT recover the
  # passthrough on its own: the host serial driver reclaims the device and the
  # guest silently loses its radio. The rules below (1) keep the host driver off
  # these devices and (2) re-attach them to the running VM on every hotplug.
  haosUsbDevices = [
    {
      name = "zigbee";
      vendor = "10c4";
      product = "ea60";
    } # SONOFF Dongle Plus MG24
    {
      name = "ir";
      vendor = "0403";
      product = "6015";
    } # FTDI FT230X UART (IR)
  ];

  # A libvirt hostdev fragment matching purely by VID:PID (no host <address>), so
  # `virsh attach-device` re-binds whichever bus/device number it currently has.
  hostdevXml =
    d:
    pkgs.writeText "haos-hostdev-${d.name}.xml" ''
      <hostdev mode='subsystem' type='usb' managed='yes'>
        <source startupPolicy='optional'>
          <vendor id='0x${d.vendor}'/>
          <product id='0x${d.product}'/>
        </source>
      </hostdev>
    '';

  # (1) Keep the host driver off it: unbind the freshly-probed USB interface from
  # whatever kernel driver (cp210x, ftdi_sio) grabbed it, so the host never holds
  # a stale /dev/ttyUSB* for a device that belongs to the VM.
  driverOff = pkgs.writeShellScript "haos-usb-driver-off" ''
    intf="$1" # e.g. 3-2:1.0
    link="/sys/bus/usb/devices/$intf/driver"
    [ -e "$link" ] || exit 0
    drv=$(basename "$(readlink -f "$link")")
    echo "$intf" > "/sys/bus/usb/drivers/$drv/unbind" 2>/dev/null || true
  '';

  # (2) Re-attach a single dongle to the running domain. `attach-device` does NOT
  # deduplicate — after a re-enumeration the device has a new bus/devnum, so a bare
  # attach would leave the old entry behind as a ghost. Detach every existing live
  # entry for this VID:PID first (each call removes one; it errors once none
  # remain), then attach whatever is currently present.
  reattach =
    d:
    pkgs.writeShellScript "haos-usb-reattach-${d.name}" ''
      virsh="${pkgs.libvirt}/bin/virsh --connect qemu:///system"
      $virsh domstate haos 2>/dev/null | grep -q running || exit 0
      i=0
      while [ "$i" -lt 5 ] && $virsh detach-device haos ${hostdevXml d} --live 2>/dev/null; do
        i=$((i + 1))
        sleep 1
      done
      $virsh attach-device haos ${hostdevXml d} --live || true
    '';
in
{
  virtualisation.libvirtd.enable = true;

  # virt-install / virt-clone for one-time VM creation; virsh ships with libvirtd.
  environment.systemPackages = [ pkgs.virt-manager ];

  services.udev.extraRules = lib.concatMapStringsSep "\n" (d: ''
    # ${d.name} dongle (${d.vendor}:${d.product}): keep the host serial driver off the
    # interface, disable USB autosuspend (the reset that triggers re-enumeration),
    # and re-attach the device to the running haos VM on every (re)enumeration.
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ATTRS{idVendor}=="${d.vendor}", ATTRS{idProduct}=="${d.product}", RUN+="${driverOff} %k"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${d.vendor}", ATTR{idProduct}=="${d.product}", ATTR{power/control}="on", TAG+="systemd", ENV{SYSTEMD_WANTS}+="haos-usb-reattach-${d.name}.service"
  '') haosUsbDevices;

  systemd.services = lib.listToAttrs (map (
    d:
    lib.nameValuePair "haos-usb-reattach-${d.name}" {
      description = "Re-attach the ${d.name} USB dongle to the haos libvirt domain";
      after = [ "libvirtd.service" ];
      wants = [ "libvirtd.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = reattach d;
      };
    }
  ) haosUsbDevices);
}

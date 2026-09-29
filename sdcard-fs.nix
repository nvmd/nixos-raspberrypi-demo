# Assumes the system will continue to reside on the installation media (sd-card),
# as there're hardly other feasible options on RPi02.
# (see also https://github.com/nvmd/nixos-raspberrypi/issues/8#issuecomment-2804912881)
# `sd-image` has lots of dependencies unnecessary for the installed system,
# replicating its disk layout
{ config, pkgs, ... }: {
  fileSystems = {
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [
        "noatime"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=1min"
      ];
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };
}
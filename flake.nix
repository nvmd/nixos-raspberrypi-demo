{
  description = ''
    Examples of NixOS systems' configuration for Raspberry Pi boards
    using nixos-raspberrypi
  '';

  nixConfig = {
    bash-prompt = "\[nixos-raspberrypi-demo\] ➜ ";
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
    connect-timeout = 5;
  };

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/develop";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
    };
  };

  outputs = { self, nixpkgs
            , nixos-raspberrypi, disko
            , nixos-anywhere, ... }@inputs: let
    allSystems = nixpkgs.lib.systems.flakeExposed;
    forSystems = systems: f: nixpkgs.lib.genAttrs systems (system: f system);       
  in {

    devShells = forSystems allSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          nixd # lsp language server for nix
          nixpkgs-fmt
          nix-output-monitor
          nixos-anywhere.packages.${system}.default
          gh
        ];
      };
    });

    nixosConfigurations = let
      common-user-config = ./common-user-config.nix;
    in {

      rpi02 = nixos-raspberrypi.lib.nixosSystemFull {
        specialArgs = inputs;
        modules = [
          ({ config, pkgs, lib, nixos-raspberrypi, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              # Hardware configuration
              raspberry-pi-02.base
              usb-gadget-ethernet
              # config.txt example
              ./pi02-configtxt.nix
            ];
          })
          # Assumes the system will continue to reside on the installation media (sd-card)
          ./sdcard-fs.nix
          # Further user configuration
          common-user-config
          ({ config, pkgs, ... }: {
            hardware.i2c.enable = true;
            environment.systemPackages = with pkgs; [
              i2c-tools
            ];
          })
        ];
      };

      rpi4 = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = inputs;
        modules = [
          ({ config, pkgs, lib, nixos-raspberrypi, disko, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              # Hardware configuration
              raspberry-pi-4.base
              raspberry-pi-4.display-vc4
              raspberry-pi-4.bluetooth
            ];
          })
          # Disk configuration
          disko.nixosModules.disko
          # WARNING: formatting disk with disko is DESTRUCTIVE, check if
          # `disko.devices.disk.main.device` is set correctly!
          ./disko-usb-btrfs.nix
          # Further user configuration
          common-user-config
          {
            boot.tmp.useTmpfs = true;
          }

          # Advanced: Use non-default kernel from kernel-firmware bundle
          ({ config, pkgs, lib, ... }: let
            kernelBundle = pkgs.linuxAndFirmware.v6_6_31;
          in {
            boot = {
              loader.raspberry-pi.firmwarePackage = kernelBundle.raspberrypifw;
              kernelPackages = kernelBundle.linuxPackages_rpi4;
            };

            nixpkgs.overlays = lib.mkAfter [
              (self: super: {
                # This is used in (modulesPath + "/hardware/all-firmware.nix") when at least 
                # enableRedistributableFirmware is enabled
                # I know no easier way to override this package
                inherit (kernelBundle) raspberrypiWirelessFirmware;
                # Some derivations want to use it as an input,
                # e.g. raspberrypi-dtbs, omxplayer, sd-image-* modules
                inherit (kernelBundle) raspberrypifw;
              })
            ];
          })

        ];
      };

      rpi5 = nixos-raspberrypi.lib.nixosSystemFull {
        specialArgs = inputs;
        modules = [
          ({ config, pkgs, lib, nixos-raspberrypi, disko, ... }: {
            imports = with nixos-raspberrypi.nixosModules; [
              # Hardware configuration
              raspberry-pi-5.base
              raspberry-pi-5.page-size-16k
              raspberry-pi-5.display-vc4
              ./pi5-configtxt.nix
            ];
          })
          # Disk configuration
          disko.nixosModules.disko
          # WARNING: formatting disk with disko is DESTRUCTIVE, check if
          # `disko.devices.disk.nvme0.device` is set correctly!
          ./disko-nvme-zfs.nix
          { networking.hostId = "8821e309"; } # NOTE: for zfs, must be unique
          # Further user configuration
          common-user-config
          {
            boot.loader.raspberry-pi.bootloader = "kernel";
            boot.tmp.useTmpfs = true;
          }
        ];
      };

    };

  };
}

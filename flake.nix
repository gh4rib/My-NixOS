{

  description = "My NixOS Flake with CachyOS Kernel";



  inputs = {

    # Point to the 25.11 stable channel

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";



    # Point to the CachyOS kernel release branch for pre-compiled binaries

    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

  };



  outputs = { self, nixpkgs, nix-cachyos-kernel, ... }: {

    nixosConfigurations."whalers0" = nixpkgs.lib.nixosSystem {

      system = "x86_64-linux";



      modules = [

        # 1. Include your hardware scan and main configuration

        ./hardware-configuration.nix

        ./configuration.nix



        # 2. Inject the CachyOS kernel overlay so 'pkgs.cachyosKernels' exists

        ({ pkgs, ... }: {

          nixpkgs.overlays = [ nix-cachyos-kernel.overlays.pinned ];

        })

      ];

    };

  };

}

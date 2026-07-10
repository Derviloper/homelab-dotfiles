{
  description = "Homelab";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      home-manager,
      deploy-rs,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./hosts/homelab
        ];
      };

      deploy.nodes.homelab = {
        hostname = "homelab";
        sshUser = "admin";
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.homelab;
        };
      };

      checks = builtins.mapAttrs (_: lib: lib.deployChecks self.deploy) deploy-rs.lib;

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;
    };
}

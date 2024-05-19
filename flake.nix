{
  description = "Remote Nix builder running in Docker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;

      systems = [ "x86_64-linux" "aarch64-linux" "x86-64-darwin" "aarch64-darwin" ];
      forAllSystems = lib.genAttrs systems;

      linuxSystemFor = system: {
        "x86_64-darwin" = "x86_64-linux";
        "aarch64-darwin" = "aarch64-linux";
      }.${system} or system;

      crossLinuxPkgs = forAllSystems (system:
        let crossSystem = linuxSystemFor system;
        in if system == crossSystem
        then nixpkgs.legacyPackages.${system}
        else import nixpkgs { inherit system crossSystem; }
      );

      cachedLinuxPkgs = forAllSystems (system:
        let linuxSystem = linuxSystemFor system;
        in nixpkgs.legacyPackages.${linuxSystem}
      );

      mkPackageSet = { pkgs, pkgsLinux }: lib.makeScope pkgs.newScope (self: {
        inherit pkgsLinux mkPackageSet;

        docker-nix-builder = self.callPackage ./pkgs/docker-nix-builder { };
        docker-nix-builder-image = self.callPackage ./pkgs/docker-nix-builder-image { };
        fix-corefoundation-cross-hook = self.callPackage ./pkgs/fix-corefoundation-cross-hook { };
      });
    in
    {
      legacyPackages = forAllSystems (system: {
        cached = mkPackageSet {
          pkgs = nixpkgs.legacyPackages.${system};
          pkgsLinux = cachedLinuxPkgs.${system};
        };

        cross = mkPackageSet {
          pkgs = nixpkgs.legacyPackages.${system};
          pkgsLinux = crossLinuxPkgs.${system};
        };

        test-hello = nixpkgs.legacyPackages.${system}.hello.overrideAttrs {
          name = "test-hello";
        };
      });

      packages = forAllSystems (system: {
        # docker-nix-builder based on linux binaries from the binary cache
        docker-nix-builder = self.legacyPackages.${system}.cached.docker-nix-builder;

        # docker-nix-builder based on cross-compiled linux binaries
        docker-nix-builder-cross = self.legacyPackages.${system}.cross.docker-nix-builder;
      });
    };
}

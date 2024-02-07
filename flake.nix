{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          pkgs = import nixpkgs { inherit system; };
          cargoToml = pkgs.lib.importTOML "${self}/Cargo.toml";
          obs-livesplit-remote = with pkgs;
            rustPlatform.buildRustPackage {
              inherit (cargoToml.package) name version;
              cargoLock.lockFile = ./Cargo.lock;
              src = self;
            };
          dockerImage = pkgs.dockerTools.buildLayeredImage {
            name = "obs-livesplit-remote";
            created = builtins.substring 0 8 self.lastModifiedDate;
            config = {
              Entrypoint =
                [ "${obs-livesplit-remote}/bin/obs-livesplit-remote" ];
              Cmd = [ "--help" ];
            };
          };
        in {
          packages = {
            inherit dockerImage;
            default = obs-livesplit-remote;
          };
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs;
              with pkgs.rustPlatform;
              [ cargo rustc rustfmt rust-analyzer ]
              ++ lib.optionals stdenv.isDarwin [ darwin.libiconv ];
          };
        };
    };
}

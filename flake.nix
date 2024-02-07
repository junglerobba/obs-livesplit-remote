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
        in {
          packages = { default = obs-livesplit-remote; };
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs;
              with pkgs.rustPlatform;
              [ cargo rustc rustfmt rust-analyzer ]
              ++ lib.optionals stdenv.isDarwin [ darwin.libiconv ];
          };
        };
    };
}

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, flake-utils, advisory-db, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        craneLib = crane.lib.${system};
        src = craneLib.cleanCargoSource (craneLib.path ./.);
        commonArgs = {
          inherit src;
          strictDeps = true;
        };
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        obs-livesplit-remote =
          craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "obs-livesplit-remote";
          created = builtins.substring 0 8 self.lastModifiedDate;
          config = {
            Entrypoint = [ "${obs-livesplit-remote}/bin/obs-livesplit-remote" ];
            Cmd = [ "--help" ];
          };
        };
      in {
        checks = {
          inherit obs-livesplit-remote;

          clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });
          fmt = craneLib.cargoFmt { inherit src; };
          audit = craneLib.cargoAudit { inherit src advisory-db; };
        };
        packages = {
          inherit dockerImage;
          default = obs-livesplit-remote;
        };
        devShells.default = craneLib.devShell {
          checks = self.checks.${system};
          packages = with pkgs; [ rust-analyzer cargo-audit ];
        };
      });
}

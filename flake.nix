{
  inputs = {
    nix.url = "github:/nixos/nix?ref=2.24.2"; # using nix 2.24.2
    nix.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    nix,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = (import nixpkgs) {
        inherit system;
      };
      lib = pkgs.lib;
    in rec {
      packages = rec {
        # a modified version of the nixos/nix image
        # re-using the upstream nix docker image generation code
        base = import (nix + "/docker.nix") {
          inherit pkgs;
          name = "nix-ci-base";
          maxLayers = 10;
          extraPkgs = with pkgs; [
            nodejs_20 # nodejs is needed for running most 3rdparty actions
            # add any other pre-installed packages here
          ];
          # change this is you want 
          channelURL = "https://nixos.org/channels/nixpkgs-24.05";
          nixConf = {
            substituters = [
              "https://cache.nixos.org/"
              "https://nix-community.cachix.org"
              # insert any other binary caches here
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              # insert the public keys for those binary caches here
            ];
            # allow using the new flake commands in our workflows
            experimental-features = ["nix-command" "flakes"]; 
          };
        };
        # make /bin/sleep available on the image
        runner = pkgs.dockerTools.buildImage {
          name = "nix-runner";
          tag = "latest";
        
          fromImage = base;
          fromImageName = null;
          fromImageTag = "latest";
        
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [
              pkgs.coreutils-full
              pkgs.nodejs
            ];
            pathsToLink = ["/bin"]; # add coreutuls (which includes sleep) to /bin
          };
        };
      };
    });
}


let

  default_pkgs = fetch_nixpkgs {
    # nixos-unstable at 2023-01-13
    rev = "6c8644fc37b6e141cbfa6c7dc8d98846c4ff0c2e";
    sha256 = "sha256:0p9843f0yz9vfyx79d5s1z4r6sz9bwjlnz04xv0xjdib9kxadivg";
  };

  fetch_nixpkgs = { rev, sha256 }:
    import (fetchTarball {
      name = "nixpkgs-${rev}";
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256;
    });

  # Some packages don't work on Apple Silicon, so build via Rosetta 2 instead.
  legacy_pkgs_config = pkgs:
    if pkgs.buildPlatform.config == "aarch64-apple-darwin"
    then { localSystem = pkgs.lib.systems.examples.x86_64-darwin; }
    else {};

in { inherit default_pkgs fetch_nixpkgs legacy_pkgs_config; }

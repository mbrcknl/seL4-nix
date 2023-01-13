with import <nixpkgs> {};
mkShell {
  packages = import ./cross-tools.nix;
}

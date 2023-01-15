with import ./lib.nix;

let

  mk_cross_toolchain = import_pkgs: pkgs_config: crossSystem:
    let pkgs_cross = import_pkgs (pkgs_config // { inherit crossSystem; });
    in with pkgs_cross.pkgsBuildTarget; [ gcc-unwrapped binutils-unwrapped ];

  mk_cross_toolchains = import_pkgs: pkgs_config:
    builtins.concatMap (mk_cross_toolchain import_pkgs pkgs_config);

  cross_tools =
    let
      import_pkgs = default_pkgs;
      pkgs = import_pkgs {};
      mk_cross = mk_cross_toolchains import_pkgs {};
      cross_tools = with pkgs.lib.systems.examples; mk_cross [
        { config = "x86_64-unknown-linux-gnu"; }
        riscv64
        riscv64-embedded
        armv7l-hf-multiplatform
        aarch64-multiplatform
      ];
    in cross_tools;

  arm_embedded_tools =
    let
      # These configurations need an older nixpkgs
      import_pkgs = fetch_nixpkgs {
        rev = "9e96b1562d67a90ca2f7cfb919f1e86b76a65a2c";
        sha256 = "sha256:0nma745rx2f2syggzl99r0mv1pmdy36nsar1wxggci647gdqriwf";
      };
      pkgs = import_pkgs {};
      mk_cross = mk_cross_toolchains import_pkgs (legacy_pkgs_config pkgs);
      cross_tools = with pkgs.lib.systems.examples; mk_cross [
        aarch64-embedded
        arm-embedded
      ];
    in cross_tools;

in cross_tools ++ arm_embedded_tools

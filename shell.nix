{ nixpkgs ? <nixpkgs>, pkgs ? import nixpkgs {} }:

with pkgs; let

  python-with-my-packages = python310.withPackages (python-pkgs: with python-pkgs;
    let
      pyfdt = buildPythonPackage rec {
        pname = "pyfdt";
        version = "0.3";
        src = fetchPypi {
          inherit pname version;
          sha256 = "1w7lp421pssfgv901103521qigwb12i6sk68lqjllfgz0lh1qq31";
        };
      };

      autopep8_1_4_3 = buildPythonPackage rec {
        pname = "autopep8";
        version = "1.4.3";
        src = fetchPypi {
          inherit pname version;
          sha256 = "13140hs3kh5k13yrp1hjlyz2xad3xs1fjkw1811gn6kybcrbblik";
        };
        propagatedBuildInputs = [
          pycodestyle
        ];
        doCheck = false;
        checkInputs = [ glibcLocales ];
        LC_ALL = "en_US.UTF-8";
      };

      cmake-format = buildPythonPackage rec {
        pname = "cmake_format";
        version = "0.4.5";
        src = fetchPypi {
          inherit pname version;
          sha256 = "0nl78yb6zdxawidp62w9wcvwkfid9kg86n52ryg9ikblqw428q0n";
        };
        propagatedBuildInputs = [
          jinja2
          pyyaml
        ];
        doCheck = false;
      };

      guardonce = buildPythonPackage rec {
        pname = "guardonce";
        version = "2.4.0";
        src = fetchPypi {
          inherit pname version;
          sha256 = "0sr7c1f9mh2vp6pkw3bgpd7crldmaksjfafy8wp5vphxk98ix2f7";
        };
        buildInputs = [
          nose
        ];
      };

      sel4-deps = buildPythonPackage rec {
        pname = "sel4-deps";
        version = "0.3.1";
        src = fetchPypi {
          inherit pname version;
          sha256 = "09xjv4gc9cwanxdhpqg2sy2pfzn2rnrnxgjdw93nqxyrbpdagd5r";
        };
        postPatch = ''
          substituteInPlace setup.py --replace bs4 beautifulsoup4
        '';
        propagatedBuildInputs = [
          six
          future
          jinja2
          lxml
          ply
          psutil
          beautifulsoup4
          sh
          pexpect
          pyaml
          jsonschema
          pyfdt
          cmake-format
          guardonce
          autopep8_1_4_3
          pyelftools
          libarchive-c
          # not listed in requirements.txt
          setuptools
        ];
      };

    in [ sel4-deps ]); 

  # Some packages don't yet work natively on Apple Silicon, but do work with Rosetta.
  legacy = if buildPlatform.config == "aarch64-apple-darwin"
    then rec { sys = { localSystem = lib.systems.examples.x86_64-darwin; }; pkgs = import nixpkgs sys; }
    else { sys = {}; inherit pkgs; };

  # In particular, cross-compilers don't currently build on Apple Silicon.
  pkgs_cross = config:
    let pkgs_base = import nixpkgs (legacy.sys // { crossSystem = { inherit config; }; });
    in pkgs_base.pkgsBuildTarget;

  cross_pkgs = {
    x86_64 = pkgs_cross "x86_64-unknown-linux-gnu";
    armv7_hf = pkgs_cross "armv7l-unknown-linux-gnueabihf";
    aarch64 = pkgs_cross "aarch64-unknown-linux-gnu";
    riscv64 = pkgs_cross "riscv64-unknown-linux-gnu";
    arm = pkgs_cross "arm-none-eabi";
  };

  cross_tools = lib.concatMap (p: [p.gcc-unwrapped p.binutils-unwrapped]) (lib.attrValues cross_pkgs);

  wrapClangWithCross = clangBinary: gccToolchains: pkgs.writeScriptBin clangBinary ''
    #!${pkgs.stdenv.shell}
    exec ${llvmPackages_9.clang-unwrapped}/bin/${clangBinary} ${toString (builtins.map (x: "-B${x}") gccToolchains)} "$@"
  '';

  # Checks don't work on macOS
  dtc = pkgs.dtc.overrideAttrs (_: { doCheck = buildPlatform.isLinux; });

  misc_tools = [
    ninja
    cmakeCurses
    python-with-my-packages
    libxml2
    dtc
    moreutils
    cpio
    strip-nondeterminism
    clang.cc
    legacy.pkgs.mlton
  ];

in mkShell {
  packages = cross_tools ++ misc_tools;
}

# Copyright 2020, Arm Limited
# Copyright 2022, Kry10 Limited
#
# SPDX-License-Identifier: MIT

let

  nixpkgs_url = (import <nixpkgs> {}).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "a923e194a3f21ed8a31367c96530a06756ed993e";
    sha256 = "sha256-Camm/RoFF72p91kES1AK+j0fYsrR6zUZhI/D9bU4HGg=";
  };

in

{ nixpkgs ? nixpkgs_url, pkgs ? import nixpkgs {} }:


with pkgs; let

  # Adapted from https://gitlab.com/arm-research/security/icecap/icecap
  python-with-my-packages = python3.withPackages (python-pkgs: with python-pkgs;
    let
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

      pyfdt = buildPythonPackage rec {
        pname = "pyfdt";
        version = "0.3";
        src = fetchPypi {
          inherit pname version;
          sha256 = "1w7lp421pssfgv901103521qigwb12i6sk68lqjllfgz0lh1qq31";
        };
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
          autopep8_1_4_3
          beautifulsoup4
          cmake-format
          future
          guardonce
          jinja2
          jsonschema
          libarchive-c
          lxml
          pexpect
          ply
          psutil
          pyaml
          pyelftools
          pyfdt
          setuptools
          six
          sh
        ];
      };

      python-subunit = buildPythonPackage rec {
        pname = "python-subunit";
        version = "1.4.0";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-BCA5koEg+/OS6MmD1g89iuG4j5Cp+P1xiN3ZwmytHkg=";
        };
        propagatedBuildInputs = [
          extras
          testtools
        ];
      };

      concurrencytest = buildPythonPackage rec {
        pname = "concurrencytest";
        version = "0.1.2";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-ZKnFtc25lJo3X8xeEUqCGA9qB8waAm05ViMK7PmAwtg=";
        };
        propagatedBuildInputs = [
          python-subunit
        ];
      };

      orderedset = buildPythonPackage rec {
        pname = "orderedset";
        version = "2.0.3";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-svXM+1qG57Oz3fGLKXecwYskZTq/nW2kvr7PM3gKbik=";
        };
        doCheck = false;
      };

      camkes-deps = buildPythonPackage rec {
        pname = "camkes-deps";
        version = "0.7.1";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-2Mfu3QLrzVjhvKM7P7T5br53xzeAG4H4uaY2dVtil4c=";
        };
        propagatedBuildInputs = [
          aenum
          concurrencytest
          hypothesis
          orderedset
          plyplus
          pycparser
          sel4-deps
          simpleeval
          sortedcontainers
        ];
      };

    in [ camkes-deps ]);

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

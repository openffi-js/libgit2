{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        windowsPkgs = import nixpkgs {
          inherit system;
          crossSystem = {
            config = "x86_64-w64-mingw32";
          };
        };

        x64DarwinPkgs = import nixpkgs {
          inherit system;
          crossSystem = {
            config = "x86_64-darwin";
          };
        };

        aarch64LinuxPkgs = import nixpkgs {
          inherit system;
          crossSystem = {
            config = "aarch64-linux";
          };
        };

        version = pkgs.lib.strings.trim (builtins.readFile ./library-version.txt);

        build =
          targetPkgs:
          targetPkgs.callPackage (
            {
              lib,
              pkgsStatic,
              stdenv,
              fetchFromGitHub,
            }:

            stdenv.mkDerivation (finalAttrs: {
              pname = "static-libgit2";
              inherit version;

              src = fetchFromGitHub {
                owner = "libgit2";
                repo = "libgit2";
                rev = "v${version}";
                hash = "sha256-/xI3v7LNhpgfjv/m+sZwYDhhYvS6kQYxiiiG3+EF8Mw=";
              };

              patches = [
                ./static-libraries.patch
              ];

              cmakeFlags = [
                "-DBUILD_SHARED_LIBS=ON"
                "-DLINK_WITH_STATIC_LIBRARIES=ON"
                "-DBUILD_CLI=OFF"
                "-DBUILD_TESTS=OFF"
                "-DUSE_GSSAPI=OFF"
              ]
              ++ lib.optionals stdenv.hostPlatform.isLinux [
                "-DGSSAPI_INCLUDE_DIR=${pkgsStatic.krb5.dev}/include"
                "-DGSSAPI_LIBRARIES=${pkgsStatic.krb5.lib}/lib/libgssapi_krb5.a"
                "-DOPENSSL_ROOT_DIR=${pkgsStatic.openssl.dev}"
                "-DOPENSSL_SSL_LIBRARY=${pkgsStatic.openssl.out}/lib/libssl.a"
                "-DOPENSSL_CRYPTO_LIBRARY=${pkgsStatic.openssl.out}/lib/libcrypto.a"
              ]
              ++ lib.optionals stdenv.hostPlatform.isWindows [
                "-DDLLTOOL=${stdenv.cc.bintools.targetPrefix}dlltool"
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [
                # openbsd headers fail with default c90
                "-DCMAKE_C_STANDARD=99"
              ];

              nativeBuildInputs = [
                (if stdenv.hostPlatform.isLinux then pkgs.pkgsMusl.cmake else pkgs.cmake)
              ]
              ++ lib.optional stdenv.hostPlatform.isLinux [
                pkgs.pkgsMusl.gcc
                pkgs.pkg-config
              ];

              buildInputs = [
                targetPkgs.zlib.static
              ]
              ++ lib.optional stdenv.hostPlatform.isLinux (
                with pkgsStatic;
                [
                  openssl
                  krb5
                ]
              );

              propagatedBuildInputs = lib.optional stdenv.hostPlatform.isDarwin pkgsStatic.libiconv;

              env =
                if stdenv.hostPlatform.isWindows then
                  {
                    NIX_CFLAGS_COMPILE = "-static-libgcc -static-libstdc++";
                  }
                else
                  { };

              passthru.tests = lib.mapAttrs (_: v: v.override { libgit2 = finalAttrs.finalPackage; }) (
                with targetPkgs;
                {
                  inherit libgit2-glib;
                  inherit (python3Packages) pygit2;
                  inherit gitstatus;
                }
              );
            })
          ) { };
      in
      {
        packages.default = build pkgs;
        packages.windows = build windowsPkgs;
        packages.x64Darwin = build x64DarwinPkgs;
        packages.aarch64Linux = build aarch64LinuxPkgs;
      }
    );
}

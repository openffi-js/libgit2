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

        version = "1.9.1";

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
              ]
              ++ lib.optionals stdenv.hostPlatform.isWindows [
                "-DDLLTOOL=${stdenv.cc.bintools.targetPrefix}dlltool"
              ]
              ++ lib.optionals stdenv.hostPlatform.isDarwin [
                # openbsd headers fail with default c90
                "-DCMAKE_C_STANDARD=99"
              ];

              nativeBuildInputs = [ pkgs.cmake ];

              buildInputs = [ targetPkgs.zlib.static ];

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
      }
    );
}

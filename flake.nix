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
            libc = "msvcrt";
          };
        };

        version = pkgs.lib.trim (builtins.readFile ./.version);

        build =
          targetPkgs:
          targetPkgs.callPackage (
            {
              lib,
              stdenv,
              pkgsStatic,
              fetchFromGitHub,
            }:

            stdenv.mkDerivation (finalAttrs: {
              pname = "static-libgit2";
              inherit version;
              # also check the following packages for updates: python3Packages.pygit2 and libgit2-glib

              outputs = [
                "lib"
                "dev"
                "out"
              ];

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
                "-DREGEX_BACKEND=builtin"
                "-DUSE_HTTP_PARSER=llhttp"
                "-DBUILD_SHARED_LIBS=ON"
                "-DLINK_WITH_STATIC_LIBRARIES=ON"
                "-DBUILD_CLI=OFF"
              ]
              ++ lib.optionals stdenv.hostPlatform.isWindows [
                "-DDLLTOOL=${stdenv.cc.bintools.targetPrefix}dlltool"
                # For ws2_32, referred to by a `*.pc` file
                "-DCMAKE_LIBRARY_PATH=${stdenv.cc.libc}/lib"
                "-DCMAKE_SYSTEM_NAME=Windows"
                "-DCMAKE_SYSTEM_PROCESSOR=x86_64"
                "-DLIBSSH2_LIBRARY=${targetPkgs.libssh2}/bin/libssh2-1.dll.a"
                "-DLLHTTP_LIBRARY=${targetPkgs.llhttp}/lib/libllhttp.dll.a"
                "-DGSSAPI_LIBRARIES="
                "-DBUILD_TESTS=OFF"
              ]
              ++ lib.optionals stdenv.hostPlatform.isOpenBSD [
                # openbsd headers fail with default c90
                "-DCMAKE_C_STANDARD=99"
              ];

              nativeBuildInputs = with pkgs; [
                cmake
                python3
                pkg-config
              ];

              buildInputs = with pkgsStatic; ([
                zlib
                openssl
                llhttp
              ]);

              env =
                if stdenv.hostPlatform.isWindows then
                  {
                    NIX_CFLAGS_COMPILE = "-static-libgcc -static-libstdc++";
                  }
                else
                  { };

              propagatedBuildInputs = lib.optional (!stdenv.hostPlatform.isLinux) [ pkgsStatic.libiconv ];

              # Don’t try to run Windows executables during cross builds
              doCheck = !stdenv.hostPlatform.isWindows;
              checkPhase = ''
                testArgs=(-v -xonline)

                # slow
                testArgs+=(-xclone::nonetwork::bad_urls)

                # failed to set permissions on ...: Operation not permitted
                testArgs+=(-xrepo::init::extended_1)
                testArgs+=(-xrepo::template::extended_with_template_and_shared_mode)

                (
                  set -x
                  ./libgit2_tests ''${testArgs[@]}
                )
              '';

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
      }
    );
}

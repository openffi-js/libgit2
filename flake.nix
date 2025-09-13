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
      in
      {
        packages.default = pkgs.callPackage (
          {
            lib,
            stdenv,
            pkgsStatic,
            fetchFromGitHub,
          }:

          stdenv.mkDerivation (finalAttrs: {
            pname = "tarunlibgit2";
            version = "1.9.1";
            # also check the following packages for updates: python3Packages.pygit2 and libgit2-glib

            outputs = [
              "lib"
              "dev"
              "out"
            ];

            src = fetchFromGitHub {
              owner = "libgit2";
              repo = "libgit2";
              rev = "v${finalAttrs.version}";
              hash = "sha256-/xI3v7LNhpgfjv/m+sZwYDhhYvS6kQYxiiiG3+EF8Mw=";
            };

            patches = [
              ./static-libraries.patch
            ];

            cmakeFlags = [
              "-DREGEX_BACKEND=pcre2"
              "-DUSE_HTTP_PARSER=llhttp"
              "-DUSE_SSH=ON"
              "-DBUILD_SHARED_LIBS=ON"
              "-DLINK_WITH_STATIC_LIBRARIES=ON"
            ]
            ++ lib.optionals stdenv.hostPlatform.isWindows [
              "-DDLLTOOL=${stdenv.cc.bintools.targetPrefix}dlltool"
              # For ws2_32, referred to by a `*.pc` file
              "-DCMAKE_LIBRARY_PATH=${stdenv.cc.libc}/lib"
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

            buildInputs = with pkgsStatic; [
              zlib
              libssh2
              openssl
              pcre
              pcre2
              llhttp
              krb5
            ];

            propagatedBuildInputs = lib.optional (!stdenv.hostPlatform.isLinux) pkgs.libiconv;

            doCheck = false;
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
              with pkgs;
              {
                inherit libgit2-glib;
                inherit (python3Packages) pygit2;
                inherit gitstatus;
              }
            );

            meta = with lib; {
              description = "Linkable library implementation of Git that you can use in your application";
              mainProgram = "git2";
              homepage = "https://libgit2.org/";
              license = licenses.gpl2Only;
              platforms = platforms.all;
              maintainers = with maintainers; [ SuperSandro2000 ];
            };
          })
        ) { };
      }
    );
}

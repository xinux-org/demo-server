{
  pkgs ? import <nixpkgs> {},
  fenix ? import <fenix> {},
  name ? "tempserver",
}: let
  # Helpful nix function
  lib = pkgs.lib;
  getLibFolder = pkg: "${pkg}/lib";

  # Manifest via Cargo.toml
  manifest = (pkgs.lib.importTOML ./Cargo.toml).workspace.package;

  # Rust Toolchain via fenix
  toolchain = fenix.packages.${pkgs.system}.fromToolchainFile {
    file = ./rust-toolchain.toml;

    # Don't worry, if you need sha256 of your toolchain,
    # just run `nix build` and copy paste correct sha256.
    sha256 = "sha256-AJ6LX/Q/Er9kS15bn9iflkUwcgYqRQxiOIL2ToVAXaU=";
  };
in
  pkgs.rustPlatform.buildRustPackage {
    # Package related things automatically
    # obtained from Cargo.toml, so you don't
    # have to do everything manually
    pname = name;
    version = manifest.version;

    # Your govnocodes
    src = pkgs.lib.cleanSource ./.;

    cargoLock = {
      lockFile = ./Cargo.lock;
      # Use this if you have dependencies from git instead
      # of crates.io in your Cargo.toml
      # outputHashes = {
      #   # Sha256 of the git repository, doesn't matter if it's monorepo
      #   "example-0.1.0" = "sha256-80EwvwMPY+rYyti8DMG4hGEpz/8Pya5TGjsbOBF0P0c=";
      # };
    };

    # Compile time dependencies
    nativeBuildInputs = with pkgs; [
      # GCC toolchain
      gcc
      gnumake
      pkg-config

      # LLVM toolchain
      cmake
      llvmPackages.llvm
      llvmPackages.clang

      # Rust
      toolchain

      # Other compile time dependencies
      postgresql
    ];

    # Runtime dependencies which will be shipped
    # with nix package
    buildInputs = with pkgs; [
      openssl
      # libressl
    ];

    fixupPhase = ''
      mkdir -p $out/mgrs
      cp -R ./crates/database/* $out/mgrs
    '';

    # Set Environment Variables
    RUST_BACKTRACE = 1;

    # Compiler LD variables
    NIX_LDFLAGS = "-L${(getLibFolder pkgs.libiconv)}  ";
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
      pkgs.gcc
      pkgs.libiconv
      pkgs.postgresql
      pkgs.llvmPackages.llvm
    ];

    meta = with lib; {
      homepage = manifest.homepage;
      description = manifest.description;
      license = with lib.licenses; [asl20 mit];
      platforms = with platforms; linux ++ darwin;
      mainProgram = "server";
      maintainers = [
        {
          name = "Example";
          email = "example@xinux.uz";
          handle = "example";
          github = "example";
          githubId = 00000000;
          keys = [
            {
              fingerprint = "0000 0000 0000 0000 0000  0000 0000 0000 0000 0000";
            }
          ];
        }
      ];
    };
  }

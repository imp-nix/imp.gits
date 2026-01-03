{
  description = "Declarative sparse checkout and multi-repo workspace composition";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    imp-fmt.url = "github:imp-nix/imp.fmt";
    imp-fmt.inputs.nixpkgs.follows = "nixpkgs";
    imp-fmt.inputs.treefmt-nix.follows = "treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-unit,
      treefmt-nix,
      imp-fmt,
    }:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f system);

      coreLib = import ./src/lib.nix { inherit lib; };
    in
    {
      lib = coreLib;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = self.packages.${system}.imp-gits;

          imp-gits = pkgs.stdenv.mkDerivation {
            pname = "imp-gits";
            version = "0.3.0";
            src = ./.;

            installPhase = ''
              mkdir -p $out/lib
              cp -r src $out/lib/

              # Install the Nu module (named without .nu so use can reference imp-gits)
              substitute bin/imp-gits.nu $out/lib/imp-gits \
                --replace '@gitsLib@' "$out/lib/src/lib.nix"
            '';

            meta = {
              description = "Declarative sparse checkout and multi-repo workspace composition";
            };
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          formatterEval = imp-fmt.lib.makeEval {
            inherit pkgs treefmt-nix;
          };
        in
        {
          formatting = formatterEval.config.build.check self;

          nix-unit =
            pkgs.runCommand "nix-unit-tests"
              {
                nativeBuildInputs = [ nix-unit.packages.${system}.default ];
              }
              ''
                export HOME=$TMPDIR
                nix-unit --expr 'import ${self}/tests { lib = import ${nixpkgs}/lib; }'
                touch $out
              '';
        }
      );

      formatter = forAllSystems (
        system:
        imp-fmt.lib.make {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit treefmt-nix;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nil
              nixfmt-rfc-style
              nushell
              git
            ];

            shellHook = ''
              export GITS_LIB="$PWD/src/lib.nix"
            '';
          };
        }
      );
    };
}

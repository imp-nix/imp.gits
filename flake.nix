{
  description = "Multi-repo workspace composition for Nix";

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

      coreLib = import ./nix/lib.nix { inherit lib; };
    in
    {
      lib = coreLib;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = self.packages.${system}.git-bits;

          git-bits = pkgs.stdenv.mkDerivation {
            pname = "git-bits";
            version = "0.1.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              mkdir -p $out/bin $out/lib
              cp -r nix src $out/lib/

              substitute bin/git-bits $out/bin/git-bits \
                --replace '@gitbitsLib@' "$out/lib/nix/lib.nix"

              chmod +x $out/bin/git-bits

              wrapProgram $out/bin/git-bits \
                --prefix PATH : ${
                  lib.makeBinPath [
                    pkgs.nix
                    pkgs.jq
                    pkgs.git
                  ]
                }
            '';

            meta = {
              description = "Multi-repo workspace composition";
              mainProgram = "git-bits";
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
                nix-unit --expr 'import ${self}/nix/tests { lib = import ${nixpkgs}/lib; }'
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
            ];
          };
        }
      );
    };
}

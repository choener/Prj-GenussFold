{
  description = ''
    GenussFold implements RNA folding with pseudoknots.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
    ghcicabal = { url = "github:choener/ghcicabal"; inputs.nixpkgs.follows = "nixpkgs"; };
  };

  outputs = { self, nixpkgs, flake-utils, ghcicabal }: let
    over = final: prev: {
      haskellPackages = (prev.haskellPackages.override{ overrides= hself: hsuper: let
          checked   = a: hself.callHackageDirect a {};
          unchecked = a: final.haskell.lib.dontCheck (checked a);
          unb       = a: final.haskell.lib.dontCheck (final.haskell.lib.unmarkBroken a);
        in {
          #fused-effects = hself.fused-effects_1_1_0_0;
          #lens          = hself.lens_4_19_2;
        };
      }).extend ( hself: hsuper: {
        ADPfusion = hself.callPackage ./ADPfusion {};
        ADPfusionSubword = hself.callPackage ./ADPfusionSubword {};
        bimaps = hself.callPackage ./bimaps {};
        DPutils = hself.callPackage ./DPutils {};
        ForestStructures = hself.callPackage ./ForestStructures {};
        FormalGrammars = hself.callPackage ./FormalGrammars {};
        GenussFold = hself.callPackage ./GenussFold {};
        OrderedBits = hself.callPackage ./OrderedBits {};
        PrimitiveArray = hself.callPackage ./PrimitiveArray {};
      });
    };
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; overlays = [ ghcicabal.overlay self.overlay ]; };
      sharedBuildInputs = with pkgs; [ llvm ];
    in {
      # update dependencies via mr, develop the package, push changes, and update the flake
      # dependencies if major changes were made or before releasing
      devShell = pkgs.haskellPackages.shellFor {
        packages = p: [
          p.ADPfusion
          p.ADPfusionSubword
          p.bimaps
          p.DPutils
          p.ForestStructures
          p.FormalGrammars
          p.GenussFold
          p.OrderedBits
          p.PrimitiveArray
        ];
        withHoogle = true;
        buildInputs = with pkgs; [
          cabal-install
          haskellPackages.haskell-language-server
          haskellPackages.hls-tactics-plugin
          nodejs # required for lsp
          pkgs.ghcicabal # be explicit to get the final package
        ] ++ sharedBuildInputs;
      }; # devShell
      apps = {
        # Data source apps
        GenussFold = { type="app"; program="${pkgs.haskellPackages.GenussFold}/bin/GenussFold"; };
      };
      packages.WienRNA = pkgs.stdenv.mkDerivation {
        name = "GenussFold";
        unpackPhase = ".";
        buildPhase = ".";
        installPhase = ''
          mkdir -p $out/bin
          ln -s "${pkgs.haskellPackages.GenussFold}/bin/GenussFold $out/bin/GenussFold
        '';
      };
    }) // { overlay = over; };
}


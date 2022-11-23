{
  inputs = {
    plutip.url = github:mlabs-haskell/plutip/8364c43ac6bc9ea140412af9a23c691adf67a18b;
    bot-plutus-interface.url = github:mlabs-haskell/bot-plutus-interface/7235aa6fba12b0cf368d9976e1e1b21ba642c038;
    bot-plutus-interface.inputs.cardano-wallet.url = github:sadMaxim/cardano-wallet/9d34b2633ace6aa32c1556d33c8c2df63dbc8f5b;
    plutip.inputs.bot-plutus-interface.follows = "bot-plutus-interface";
    plutip.inputs.haskell-nix.follows = "bot-plutus-interface/haskell-nix";
    plutip.inputs.iohk-nix.follows = "bot-plutus-interface/iohk-nix";
    plutip.inputs.nixpkgs.follows = "bot-plutus-interface/nixpkgs";
    cardano-transaction-lib.url = github:Plutonomicon/cardano-transaction-lib/v2.0.0;
    cardano-transaction-lib.inputs.plutip.follows = "plutip";
    cardano-transaction-lib.inputs.haskell-nix.follows = "plutip/haskell-nix";
    cardano-transaction-lib.inputs.nixpkgs.follows = "plutip/nixpkgs";

    nixpkgs.follows = "cardano-transaction-lib/nixpkgs";
    haskell-nix.follows = "cardano-transaction-lib/haskell-nix";
  };

  outputs = inputs@{ self, nixpkgs, haskell-nix, cardano-transaction-lib, plutip, ... }:
    let
      # GENERAL
      # supportedSystems = with nixpkgs.lib.systems.supported; tier1 ++ tier2 ++ tier3;
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
      perSystem = nixpkgs.lib.genAttrs supportedSystems;

      nixpkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [
          haskell-nix.overlay
          cardano-transaction-lib.overlays.ctl-server
          cardano-transaction-lib.overlays.purescript
          cardano-transaction-lib.overlays.runtime
        ];
        inherit (haskell-nix) config;
      };
      nixpkgsFor' = system: import nixpkgs { inherit system; };

      formatCheckFor = system:
        let
          pkgs = nixpkgsFor system;
          pkgs' = nixpkgsFor' system;
          nativeBuildInputs = [
            pkgs'.fd
            pkgs'.git
            pkgs'.nixpkgs-fmt
            pkgs.easy-ps.purs-tidy
          ];
          formatCheck = pkgs.runCommand "format-check"
            {
              inherit nativeBuildInputs;
            }
            ''
              cd ${self}
              make format_check
              mkdir $out
            '';
          inherit (pkgs'.lib) concatStringsSep;
          otherBuildInputs = [ pkgs'.bash pkgs'.coreutils pkgs'.findutils pkgs'.gnumake pkgs'.nix ];
          format = pkgs.writeScript "format"
            ''
              export PATH=${concatStringsSep ":" (map (b: "${b}/bin") (otherBuildInputs ++ nativeBuildInputs))}
              make format
            '';
        in
        {
          inherit format formatCheck;
        }
      ;

      offchain = {
        projectFor = system:
          let
            pkgs = nixpkgsFor system;
          in
          pkgs.purescriptProject {
            inherit pkgs;
            projectName = "odc-mre";
            strictComp = false; # TODO: this should be eventually removed
            src = ./offchain;
            packageJson = ./offchain/package.json;
            packageLock = ./offchain/package-lock.json;
            shell = {
              packageLockOnly = true;
              packages = with pkgs; [
                bashInteractive
                ctl-server
                docker
                fd
                nodePackages.eslint
                nodePackages.prettier
                ogmios
                ogmios-datum-cache
                plutip-server
                postgresql
                easy-ps.purescript-language-server
                nodejs-14_x.pkgs.http-server
              ];
              shellHook =
                ''
                  export LC_CTYPE=C.UTF-8
                  export LC_ALL=C.UTF-8
                  export LANG=C.UTF-8
                '';
            };
          };
      };
    in
    {
      inherit nixpkgsFor;

      offchain = {
        project = perSystem offchain.projectFor;
        flake = perSystem (system: (offchain.projectFor system).flake { });
      };

      packages = perSystem (system:
        {
          odc-mre = self.offchain.project.${system}.buildPursProject { };
          odc-mre-web = self.offchain.project.${system}.bundlePursProject {
            main = "Web.Main";
            webpackConfig = "src/assets/webpack.config.js";
            bundledModuleName = "src/assets/output.js";
            entrypoint = "src/assets/index.js";
          };
          ctl-runtime = (nixpkgsFor system).buildCtlRuntime { };
        }
      );

      devShells = perSystem (system: {
        offchain = self.offchain.project.${system}.devShell;
      });

      apps = perSystem (system: {
        ctl-runtime = (nixpkgsFor system).launchCtlRuntime { };
        docs = self.offchain.project.${system}.launchSearchablePursDocs { };
        ctl-docs = cardano-transaction-lib.apps.${system}.docs;
        format = {
          type = "app";
          program = (formatCheckFor system).format.outPath;
        };
        odc-mre-serve = {
          type = "app";
          program =
            let
              pkgs = nixpkgsFor system;
              program = pkgs.writeScript "odc-mre-serve"
                ''
                  ${pkgs.nodejs-14_x.pkgs.http-server}/bin/http-server \
                    -a 127.0.0.1 -p 8081 \
                    ${self.packages.${system}.odc-mre-web}/dist
                '';
            in
            program.outPath;
        };
      });
    };
}

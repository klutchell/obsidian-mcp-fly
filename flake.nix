{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: {
        default =
          let
            obsidian-headless = pkgs.buildNpmPackage {
              pname = "obsidian-headless";
              version = "0.0.3";
              src = ./.;
              npmDepsHash = "sha256-bL8A/Su1oL5eC4bNYy3TzeMgPtlSurACDiHIty45op8=";
              dontNpmBuild = true;
            };
          in pkgs.mkShell {
            packages = [
              pkgs.flyctl
              obsidian-headless
            ];
          };
      });
    };
}

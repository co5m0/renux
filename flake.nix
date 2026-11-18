{
  description = "Renux, a native Linux client for Rex";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # GitHub flake archives omit submodules. Keep this revision at the Ghostty gitlink.
  inputs.ghostty = {
    url = "github:ghostty-org/ghostty/e95bed63330cc921f3cf2fe3d14e024396b09d43";
    flake = false;
  };

  outputs = { self, nixpkgs, ghostty }:
    let
      forLinux = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in {
      packages = forLinux (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in rec {
          default = renux;
          renux = pkgs.stdenv.mkDerivation {
            pname = "renux";
            version = "0.1.0";
            src = self;
            postPatch = ''
              mkdir -p third_party
              rm -rf third_party/ghostty
              ln -s ${ghostty} third_party/ghostty
            '';
            nativeBuildInputs = with pkgs; [ zig_0_17 pkg-config wrapGAppsHook4 ];
            buildInputs = with pkgs; [ gtk4 libadwaita librsvg poppler libepoxy fontconfig ];
            zigBuildFlags = [ "--system" "${pkgs.callPackage (ghostty + "/deps/packages.nix") {}}" "-Doptimize=ReleaseFast" ];
            meta.mainProgram = "renux";
          };
        });
      devShells = forLinux (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          inputsFrom = [ self.packages.${system}.renux ];
        };
      });
    };
}

{
  description = "A very basic dune-project flake.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dunix.url = "github:eureka-cpu/dunix/master";
  };
  outputs = { self, nixpkgs, dunix }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
        f (import nixpkgs {
          inherit system;
          overlays = [ dunix.overlays.default ];
        }));
    in
    {
      packages = eachSystem (pkgs:
        {
          default =
            let
              dune-project = pkgs.importDuneProject ./dune-project;
              # Populate derivation build inputs from dune-project package dependencies
              depends =
                let
                  depends = builtins.listToAttrs (map
                    (dep:
                      {
                        name = dep;
                        value = pkgs.ocamlPackages.${dep};
                      })
                    (builtins.attrNames
                      (builtins.foldl' (acc: dep: acc // dep)
                        { }
                        dune-project.package.depends)));
                in
                # Remove dependencies which may be missing from nixpkgs or intrinsic to buildDunePackage
                removeAttrs depends [ "dune" "ocaml" ];
            in
            pkgs.ocamlPackages.buildDunePackage (finalAttrs: {
              # Derive derivation name and version from dune-project toplevel or package name and version
              inherit (dune-project) version;
              pname = dune-project.package.name;
              src = pkgs.lib.cleanSource ./.;
              buildInputs = builtins.attrValues (depends // {
                # inherit (pkgs) hello;
              });
              doCheck = true;
              checkPhase = '' # Check that the generated opam file matches source
                if ! diff "${finalAttrs.src}/${dune-project.name}.opam" "./${dune-project.name}.opam"; then
                  echo "Error: Generated opam file does not match source opam file"
                  exit 1
                fi
              '';
              meta =
                let
                  inherit (dune-project.source) type owner repo;
                  # Populate maintainers from dune-project maintainers (must be a nixpkgs maintainer)
                  maintainers = map (maintainer: pkgs.lib.maintainers.${(builtins.elemAt (builtins.split " " maintainer) 0)}) dune-project.maintainers;
                in
                {
                  inherit maintainers;
                  # Include dune-project package synopsis and description
                  description = dune-project.package.synopsis;
                  longDescription = dune-project.package.description;
                  # Populate source homepage from dune-project source
                  homepage = "https://${type}.com/${owner}/${repo}";
                  # Derive license from dune-project license via spdxId
                  license = pkgs.lib.getLicenseFromSpdxId dune-project.license;
                };
            });
        });

      devShells = eachSystem (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
          packages = builtins.attrValues {
            inherit (pkgs) ocamlformat nil;
            inherit (pkgs.ocamlPackages) ocaml-lsp odoc;
          };
          shellHook = ''
            dune build # Ensure build artifacts exist for LSP
          '';
        };
      });
    };
}

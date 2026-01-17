# dunix

Parse dune-project files into nix expressions.

## Usage with `buildDunePackage`

Below is a minimal example of how to use `dunix` to its fullest potential
by treating `dune-project` as the singular source of truth. Update `dune-project`
and it will automatically populate `buildDunePackage` for you.

```nix
{
  description = "A very basic dune-project flake.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    dunix.url = "github:eureka-cpu/dunix/master";
  };
  outputs = { self, nixpkgs, dunix, ... }:
    let
      let system = "x86_64-linux";
      let pkgs = import nixpkgs {
        inherit system;
        overlays = [ dunix.overlays.default ];
      };
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
        removeAttrs depends [ "ocaml" ];
    in
    {
      package.${system} = pkgs.buildDunePackage (finalAttrs: {
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
    };
}
```

## Testing

```sh
$ nix repl
Nix 2.26.3
Type :? for help.
nix-repl> :lf .
nix-repl> pkgs = import <nixpkgs> { overlays = [ outputs.overlays.default ]; }
nix-repl> pkgs.importDuneProject <DUNE_PROJECT_FILE_PATH>
```

Output of [eureka-cpu/ns/dune-project](https://github.com/eureka-cpu/ns):
```nix
{
  authors = [ "eureka-cpu <github.eureka@gmail.com>" ];
  generate_opam_files = "true";
  lang = { dune = "3.20"; };
  license = "MIT";
  maintainers = [ "eureka-cpu <github.eureka@gmail.com>" ];
  name = "ns";
  package = {
    depends = [
      {
        ocaml = [ ];
      }
      {
        cmdliner = [ ">= 2.1.0" ];
      }
      {
        bos = [ ">= 0.2.1" ];
      }
      {
        dune-build-info = [ ">= 3.20.2" ];
      }
    ];
    description = "Literally the simplest script in existence for changing directories and entering a nix shell.";
    name = "ns";
    synopsis = "A unified interface for nix shell.";
    tags = [
      "nix"
      "devshell"
      "nix-shell"
      "flakes"
      "nix-command"
    ];
  };
  source = {
    owner = "eureka-cpu";
    repo = "ns";
    type = "github";
  };
  version = "0.3.1";
}
```

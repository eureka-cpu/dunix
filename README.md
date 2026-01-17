# dunix

Parse dune-project files into nix expressions.

## Usage with `buildDunePackage`

Below is a minimal examples, though theoretically you could use the information
from the parsed dune-project file to make assertions about dependencies, match
on `spdxId`s of licenses, ensure the dune language version matches and more.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.dunix.url = "github:eureka-cpu/dunix/master";
  outputs = { self, nixpkgs, dunix, ... }:
    let
      let system = "x86_64-linux";
      let pkgs = import nixpkgs {
        inherit system;
        overlays = [ dunix.overlays.default ];
      };
      dune-project = pkgs.importDuneProject ./dune-project;
    in
    {
      package.${system} = pkgs.buildDunePackage {
        inherit (dune-project) version;
        pname = dune-project.name;
        src = pkgs.lib.cleanSource ./.;
        meta.description = dune-project.description;
      };
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

Output of [eureka-cpu/ns](https://github.com/eureka-cpu/ns):
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

{
  description = "Convert dune-project files to Nix values.";
  outputs = _: {
    overlays.default = import ./overlay.nix;
    templates =
      let
        project = {
          description = "A very basic dune-project flake.";
          path = ./templates/project;
        };
      in
      {
        inherit project;
        default = project;
      };
  };
}

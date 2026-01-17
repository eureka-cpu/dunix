{
  description = "Convert dune-project files to Nix values.";
  outputs = { self }: { overlays.default = import ./overlay.nix; };
}

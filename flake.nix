{
  description = "Convert an S-expression string to a Nix value.";
  outputs = { self }: { overlays.default = import ./overlay.nix; };
}

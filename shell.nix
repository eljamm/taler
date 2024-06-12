{
  pkgs ? import <nixpkgs> { },
  ngipkgs ?
    (builtins.getFlake "github:ngi-nix/ngipkgs/114678c31ca82f6cdc618563027e25695f533c5d")
    .outputs.packages.x86_64-linux,
}:
pkgs.mkShell {
  buildInputs = [
    ngipkgs.taler-wallet-core
    pkgs.jq
    pkgs.taler-exchange
    pkgs.taler-merchant
  ];
}

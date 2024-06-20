{
  pkgs ? import <nixpkgs> { },
  ngipkgs ?
    (builtins.getFlake "github:ngi-nix/ngipkgs/4dfe0968fc1c00d728231826614f2297d5bf3a88")
    .outputs.packages.x86_64-linux,
}:
pkgs.mkShell {
  buildInputs = [
    ngipkgs.taler-wallet-core
    ngipkgs.libeufin

    pkgs.taler-exchange
    pkgs.taler-merchant

    pkgs.jdk17_headless # TODO: fix dependency for libeufin

    pkgs.jq
    pkgs.lurk # alternative to strace
  ];
}

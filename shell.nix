let
  pkgs = import <nixpkgs> {
    config = { };
    overlays = [ ];
  };
  wipPkgs =
    import
      (fetchTarball "https://github.com/Atemu/nixpkgs/archive/5e5ab78703eb0cd17098c71def383a489310b2bc.tar.gz")
      { };
  ngipkgs =
    (builtins.getFlake "github:ngi-nix/ngipkgs/a9de64c60a167f74524102b773496b4531b23294")
    .outputs.packages.x86_64-linux;
  ngipkgs-taler =
    (builtins.getFlake "github:ngi-nix/ngipkgs/4dfe0968fc1c00d728231826614f2297d5bf3a88")
    .outputs.packages.x86_64-linux;
in
pkgs.mkShell {
  buildInputs = [
    ngipkgs-taler.taler-wallet-core
    wipPkgs.libeufin

    pkgs.taler-exchange
    pkgs.taler-merchant

    pkgs.jq
    pkgs.lurk # alternative to strace
  ];
}

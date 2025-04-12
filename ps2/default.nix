inputs@{ flake-utils, ... }:
flake-utils.lib.meld inputs [
  ./ee
]

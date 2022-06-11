#!/bin/sh

# TODO: automatically get the remaps from foundry.toml
mkdir -p ./@ds/ && sudo mount --bind ./lib/ds-test/src/ ./@ds/
mkdir -p ./@std/ && sudo mount --bind ./lib/forge-std/src/ ./@std/
mkdir -p ./@rari-capital/solmate/ && sudo mount --bind ./lib/solmate/src/ ./@rari-capital/solmate/
mkdir -p ./@openzeppelin/ && sudo mount --bind ./lib/openzeppelin-contracts/ ./@openzeppelin/

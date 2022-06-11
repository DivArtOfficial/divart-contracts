#!/bin/sh

# TODO: automatically get the remaps from foundry.toml
sudo umount ./@ds/
sudo umount ./@std/
sudo umount ./@openzeppelin/
rm -r ./@*

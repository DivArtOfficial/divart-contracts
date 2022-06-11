#!/bin/sh

echo Which contract do you want to flatten \(eg Greeter\)?
read contract

rm -r flattened.txt

forge flatten ./src/${contract}.sol > flattened.txt

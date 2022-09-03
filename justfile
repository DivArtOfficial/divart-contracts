set dotenv-load

all: install build

install:
    forge install

update:
    forge update

solc:
	pip3 install solc-select
	solc-select install 0.8.14
	solc-select use 0.8.14

build:
    forge build --force

test:
    forge test --force -vvv

clean:
    forge clean

gas-report:
    forge test --gas-report

flatten contract:
    forge flatten {{contract}}

slither contract:
    slither {{contract}}

format:
    prettier --write src/**/*.sol \
    && prettier --write src/*.sol \
    && prettier --write test/**/*.sol \
    && prettier --write test/*.sol \
    && prettier --write script/**/*.sol \
    && prettier --write script/*.sol

restore-submodules:
    #!/bin/sh
    set -e
    git config -f .gitmodules --get-regexp '^submodule\..*\.path$' |
        while read path_key path
        do
            url_key=$(echo $path_key | sed 's/\.path/.url/')
            url=$(git config -f .gitmodules --get "$url_key")
            git submodule add $url $path
        done

deploy-genesis:
    #!/bin/sh

    ls config.json >/dev/null 2>&1 || \
    { echo -e "Missing config.json, you can use config.example.json as an example config file." && exit 1; }

    forge script "script/DeployGenesis.s.sol" \
    --rpc-url $RPC_NODE_URL \
    --sender $SENDER_ADDRESS \
    --keystores $KEYSTORE_PATH \
    --slow \
    --broadcast \
    --with-gas-price 1000000000 \
    -vvvv

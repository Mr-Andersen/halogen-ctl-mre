#!/bin/sh

set -x

export BROWSER_RUNTIME=1
spago bundle-module --no-install -m Web.Main \
  --to src/assets/output.js && \
mkdir -p ./dist && \
webpack --mode=production -c src/assets/webpack.config.js -o ./dist \
  --entry ./src/assets/index.js

# Recommended usage:
# nix develop .#offchain
# cd offchain
# ./web/assets/bundle.sh && http-server -a 127.0.0.1 dist/

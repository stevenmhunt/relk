#!/usr/bin/env bash

PATH_DIR="/usr/local/bin/relk"
SCRIPT_DIR="/usr/local/share/relk"

# create script directory and copy shared files.
mkdir -p "$SCRIPT_DIR"
cp -r -f "./shared/." "$SCRIPT_DIR"

# copy dist file to bin directory.
cp -f "./dist/relk" $PATH_DIR

chmod +x $PATH_DIR
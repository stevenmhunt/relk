#!/usr/bin/env bash

PATH_DIR="/usr/local/bin/conch"
SCRIPT_DIR="/usr/local/share/conch"

# create script directory and copy support files.
mkdir -p "$SCRIPT_DIR"
cp -r -f "./src/." "$SCRIPT_DIR"

# create entrypoint and copy to bin directory.
echo "#!/usr/bin/env bash
source '$SCRIPT_DIR/conch.cli.sh'
conch_main \"\$@\"" > $PATH_DIR

chmod +x $PATH_DIR
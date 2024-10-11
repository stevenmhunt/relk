PATH_DIR="/usr/local/bin/conk"
SCRIPT_DIR="/usr/local/share/conk"

# create script directory and copy support files.
mkdir -p "$SCRIPT_DIR"
cp -r -f "./src/." "$SCRIPT_DIR"

# create entrypoint and copy to bin directory.
echo "#!/bin/bash
source '$SCRIPT_DIR/conk.cli.sh'
conk_cli_main \"\$@\"" > $PATH_DIR

chmod +x $PATH_DIR
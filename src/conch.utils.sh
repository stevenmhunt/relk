#!/usr/bin/env bash
# Conch Utils Library
# Licensed under MIT License

export DELIM_KEY=','
export DELIM_COL='|'

# converts a string into Bash-safe output.
conch_util_escape() {
    INPUT="$1"
    echo "$INPUT" | sed 's/[][\*^$()+?|]/\\&/g'
}
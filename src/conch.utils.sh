#!/usr/bin/env bash
# Conch Utils Library
# Licensed under MIT License

export DELIM_KEY=','
export DELIM_COL='|'

conch_util_escape() {
    INPUT="$1"
    echo "$INPUT" | xargs -I{} printf '%q\n' "{}" | sed "s/^'//; s/'$//"
}
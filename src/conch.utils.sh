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

# breaks up a conditional expression into a list of tokens
conch_util_tokenize() {
    INPUT="$1"
    RESULT=$(echo "$INPUT" | sed 's/(/ ( /g; s/)/ ) /g')
    echo "$RESULT" | grep -oP "'[^']*'|[^[:space:]]+"
}
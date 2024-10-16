################################
# Relk Utils Library
# Licensed under MIT License
################################

export DELIM_KEY=','
export DELIM_COL='|'
export DELIM_CMD=':'

# <private>
# converts a string into Bash-safe output.
# parameters: 1: input
relk_util_escape() {
    local input="$1"
    echo "$input" | sed 's/[][\*^$()+?|]/\\&/g'
}

# <private>
# breaks up an expression into a list of tokens
# parameters: 1: input
relk_util_tokenize() {
    local input="$1"
    echo "$input" | sed 's/(/ ( /g; s/)/ ) /g' | awk '{
        match($0, /'\''[^'\'']*'\''|[^[:space:]]+/)
        while (RSTART > 0) {
            print substr($0, RSTART, RLENGTH)
            $0 = substr($0, RSTART + RLENGTH)
            match($0, /'\''[^'\'']*'\''|[^[:space:]]+/)
        }
    }'
}

# <private>
# Validates the specified key name.
# parameters: 1: key
relk_util_validate_key_name() {
    local key="$1"
    if [[ "$key" = *[\|,\$\#\%\&\@\^\*\(\)\[\]\{\}\<\>=!\'\"\:\;]* ]]; then
        exit 6
    fi
    return 0
}

# <private>
# Validates the specified key value.
# parameters: 1: key
relk_util_validate_key_value() {
    local key="$1"
    if [[ "$key" = *[\|]* ]]; then
        exit 7
    fi
    return 0
}

# <private>
# Unwraps a quoted string.
# parameters: 1: input
relk_util_unwrap() {
    local input="$1"
    
    # Check if the string starts and ends with a single quote
    if [[ "$input" =~ ^\'[^\']*\'$ ]]; then
        # Remove the leading and trailing single quotes
        input="${input:1:-1}"
    fi
    
    echo "$input"
}

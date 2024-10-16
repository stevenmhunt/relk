################################
# Relk Utils Library
# Licensed under MIT License
################################

export DELIM_KEY=','
export DELIM_COL='|'

# converts a string into Bash-safe output.
relk_util_escape() {
    local input="$1"
    echo "$input" | sed 's/[][\*^$()+?|]/\\&/g'
}

# breaks up a conditional expression into a list of tokens
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

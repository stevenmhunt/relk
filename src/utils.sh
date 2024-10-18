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
    echo "$input" | sed "s/[\$|\`]/\\\&/g"
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
    
    echo "$input" | sed "s/[\$|\`\"]/\\\&/g"
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
    if [[ "$key" = *[\|,\$\#%\&\@^\*\(\)\[\]\{\}\<\>=!\'\":\;]* ]]; then
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

relk_util_list_append() {
    echo "$1,$2"
}

relk_util_list_prepend() {
    echo "$2,$1"
}

relk_util_list_remove_first() {
    echo "$1" | cut -d ',' -f 2-
}

relk_util_list_remove_last() {
    local result="$1"
    echo "${result%,*}"
}

relk_util_list_remove() {
    local list="$1"
    local value_to_remove="$2"
    local IFS=','

    read -ra arr <<< "$list"
    new_arr=()
    for item in "${arr[@]}"; do
        if [[ "$item" != "$value_to_remove" ]]; then
            new_arr+=("$item")
        fi
    done
    echo "${new_arr[*]}" | sed 's/ /,/g'
}

relk_util_list_remove_at() {
    local list="$1"
    local index="$2"
    local IFS=','

    read -ra arr <<< "$list"
    if (( index < 1 || index > ${#arr[@]} )); then
        return 1
    fi

    unset 'arr[index-1]'
    echo "${arr[*]}" | sed 's/ /,/g' 
}

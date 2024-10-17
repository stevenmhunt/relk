################################
# Relk Args Library
# Licensed under MIT License
################################

# <private>
# Parses command-line arguments where a <key> is present.
# parameters: <args...>
# exports: $KEY
relk_args_parse_key() {
    shift 1
    export KEY=$1
    relk_args_parse "$@"
}

# <private>
# Parses command-line arguments.
# parameters: <args...>
# exports: $VALUE, $VALUE_TYPE, $DEBUG, $KEYS, $NAMESPACE, $SOURCE, $SOURCE_PROVIDER, $SOURCE_PATH, $FORCE_READ, $FORCE_WRITE
relk_args_parse() {
    shift 1
    local args
    args=( $(relk_get_context) )
    args+=( "$@" )

    relk_debug "args_parse() args: $@"

    export VALUE="$1"
    export VALUE_TYPE="s"
    # handle template type.
    if [ "$1" == "-t" ]; then
        VALUE="$2"
        VALUE_TYPE="t"
    elif [ "$1" == "-l" ]; then
        VALUE="$2"
        VALUE_TYPE="l"
    fi

    export DEBUG=$(relk_args_get_debug "${args[@]}")
    export ATTRIBUTES=$(relk_args_get_attribute_keys "${args[@]}")
    export EXTENSIONS=$(relk_args_get_extension_keys "${args[@]}")
    export KEYS=$(relk_args_get_constraint_keys "${args[@]}")
    export NAMESPACE=$(relk_args_get_namespace "${args[@]}")
    export SOURCE=$(relk_args_get_source "${args[@]}")
    export SOURCE_PROVIDER=$(relk_args_get_source_provider $SOURCE)
    export SOURCE_PATH=$(relk_args_get_source_path $SOURCE)
    export FORCE_READ=$(relk_args_get_force "${args[@]}")
    export FORCE_WRITE="$FORCE_READ"

    relk_debug "args_parse() -> source: $SOURCE, namespace: $NAMESPACE, keys: $KEYS, attributes: $ATTRIBUTES"
}

# <private>
# Gets the provider name from a source.
# parameters: 1: source
relk_args_get_source_provider() {
    echo "$1" | cut -d ":" -f 1
}

# <provider>
# Gets the source path from a source.
# parameters: 1: source
relk_args_get_source_path() {
    echo "$1" | cut -d ":" -f 2-
}

# <private>
# Extracts the constraint keys from arguments.
# parameters: ...args
relk_args_get_constraint_keys() {
    local args=("$@")
    declare -A keys_dict

    # Loop through all arguments and check for the "-k" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-k" && $((i+1)) -lt ${#args[@]} ]]; then
            local key_value="${args[$((i+1))]}"
            local key="${key_value%%=*}"
            local value="${key_value#*=}"
            keys_dict["$key"]="$value"
        fi
    done

    # Convert the associative array back to a normal array
    local keys=()
    for key in "${!keys_dict[@]}"; do
        keys+=("$key=${keys_dict[$key]}")
    done

    # Sort the keys
    local sorted_keys=$(printf "%s\n" "${keys[@]}" | sort)
    echo -n "${sorted_keys}" | tr '\n' "$DELIM_KEY"
}

# <private>
# Extracts the attribute keys from arguments.
# parameters: ...args
relk_args_get_attribute_keys() {
    local args=("$@")
    declare -A keys_dict

    # Loop through all arguments and check for the "-a" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-a" && $((i+1)) -lt ${#args[@]} ]]; then
            local key_value="${args[$((i+1))]}"
            local key="${key_value%%=*}"
            local value="${key_value#*=}"
            keys_dict["$key"]="$value"
        fi
    done

    # Convert the associative array back to a normal array
    local keys=()
    for key in "${!keys_dict[@]}"; do
        keys+=("$key=${keys_dict[$key]}")
    done

    # Sort the keys
    local value_type=$([ -n "$VALUE_TYPE" ] && echo "$VALUE_TYPE,")
    local sorted_keys=$(printf "%s\n" "${keys[@]}" | sort)
    echo -n "${sorted_keys}" | tr '\n' "$DELIM_KEY"
}

# <private>
# Extracts the extension keys from arguments.
# parameters: ...args
relk_args_get_extension_keys() {
    local args=("$@")
    declare -A keys_dict

    # Loop through all arguments and check for the "-e" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-e" && $((i+1)) -lt ${#args[@]} ]]; then
            local key_value="${args[$((i+1))]}"
            local key="${key_value%%=*}"
            local value="${key_value#*=}"
            keys_dict["$key"]="$value"
        fi
    done

    # Convert the associative array back to a normal array
    local keys=()
    for key in "${!keys_dict[@]}"; do
        keys+=("${keys_dict[$key]}")
    done

    # Sort the keys
    local value_type=$([ -n "$VALUE_TYPE" ] && echo "$VALUE_TYPE,")
    local sorted_keys=$(printf "%s\n" "${keys[@]}" | sort)
    echo -n "${sorted_keys}" | tr '\n' "$DELIM_KEY"
}

# <private>
# Extracts the namespace from arguments.
# parameters: ...args
relk_args_get_namespace() {
    local args=("$@")
    local namespace="default"

    # Loop through all arguments to find the last "-n" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-n" && $((i+1)) -lt ${#args[@]} ]]; then
            namespace="${args[$((i+1))]}"  # Update the namespace with the last occurrence
            break
        fi
    done

    # Output the last found namespace value
    echo -n "$namespace"
}

# <private>
# Extracts the source from arguments.
# parameters: ...args
relk_args_get_source() {
    local args=("$@")
    local source="file:$HOME/.relkfile"

    # Loop through all arguments to find the last "-s" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-s" && $((i+1)) -lt ${#args[@]} ]]; then
            # Update the source with the last occurrence
            source="${args[$((i+1))]}"
            break
        fi
    done

    # Output the last found source value
    echo -n "$source"
}

# <private>
# Extracts the FORCE_READ and FORCE_WRITE flag from arguments.
# parameters: ...args
relk_args_get_force() {
    local args=("$@")

    # Loop through all the arguments to check for the "-f" flag
    for arg in "${args[@]}"; do
        if [[ "$arg" == "-f" ]]; then
            echo "1"
            return
        fi
    done

    echo "0"
}

# <private>
# Extracts the DEBUG flag from arguments.
# parameters: ...args
relk_args_get_debug() {
    local args=("$@")

    # check if the DEBUG variable is already set.
    if [ "$DEBUG" == "1" ]; then
        echo "1"
        return
    fi

    # Loop through all the arguments to check for the "--debug" flag
    for arg in "${args[@]}"; do
        if [[ "$arg" == "--debug" ]]; then
            echo "1"
            return
        fi
    done

    echo "0"
}

# <private>
# Gets the context from the .relk file and parent directories.
relk_get_context() {
    local context_file=".relk"
    local result=""

    # Function to read and append content from .relk files
    append_context_file() {
        local file="$1"
        if [ -f "$file" ]; then
            result+=$(cat "$file")
            result+=$'\n'
        fi
    }

    # Start from the current directory and move up through parent directories
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        append_context_file "$dir/$context_file"
        dir=$(dirname "$dir")
    done

    # Check for ~/.relk
    append_context_file "$HOME/$context_file"

    echo -n "$result"
}

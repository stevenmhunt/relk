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
# exports: $VALUE, $VALUE_TYPE, $DEBUG, $ATTRIBUTES, $EXTENSIONS, $KEYS, $NAMESPACE, $SOURCE, $SOURCE_PROVIDER, $SOURCE_PATH, $FORCE_READ, $FORCE_WRITE
relk_args_parse() {
    shift 1
    local args
    args=( $(relk_get_context) )
    args+=( "$@" )

    export DEBUG=$(relk_args_get_debug "${args[@]}")

    relk_debug "args_parse() args: $@"

    export VALUE="$1"
    export VALUE_TYPE="s"
    # handle template type.
    if [[ "$1" == "-t" || "$1" == "-t:"* ]]; then
        VALUE="$2"
        VALUE_TYPE=$(echo "$1" | cut -d '-' -f 2-)
    elif [ "$1" == "-l" ];then
        VALUE="$2"
        VALUE_TYPE="l"
    fi

    local key_value
    local key
    local value
    declare -A attribute_keys extension_keys constraint_keys
    local namespace="default"
    local source="file:$HOME/.relkfile"
    local force_read=0
    local list_operation
    local allow_shell
    local engine

    # Iterate through all arguments
    for ((i=0; i<${#args[@]}; i++)); do
        case "${args[$i]}" in
            "-a")
                if (( i+1 < ${#args[@]} )); then
                    key_value="${args[$((i+1))]}"
                    key="${key_value%%=*}"
                    value="${key_value#*=}"
                    attribute_keys["$key"]="$value"
                    ((i++))
                fi
                ;;
            "-e")
                if (( i+1 < ${#args[@]} )); then
                    key_value="${args[$((i+1))]}"
                    extension_keys["$key_value"]="$key_value"
                    ((i++))
                fi
                ;;
            "-k")
                if (( i+1 < ${#args[@]} )); then
                    key_value="${args[$((i+1))]}"
                    key="${key_value%%=*}"
                    value="${key_value#*=}"
                    constraint_keys["$key"]="$value"
                    ((i++))
                fi
                ;;
            "-n")
                if (( i+1 < ${#args[@]} )); then
                    namespace="${args[$((i+1))]}"
                    ((i++))
                fi
                ;;
            "-s")
                if (( i+1 < ${#args[@]} )); then
                    source="${args[$((i+1))]}"
                    ((i++))
                fi
                ;;
            "-f")
                force_read=1
                ;;
            "--append")
                list_operation="append"
                ;;
            "--prepend")
                list_operation="prepend"
                ;;
            "--allow-shell")
                if [ "$allow_shell" != "0" ]; then
                    allow_shell=1
                fi
                ;;
            "--no-shell")
                allow_shell=0
                ;;
            "--engine")
                if (( i+1 < ${#args[@]} )); then
                    engine="${args[$((i+1))]}"
                    ((i++))
                fi
                ;;
        esac
    done

    # Convert associative arrays to sorted lists
    local constraints=()
    local attributes=()
    local extensions=()

    for key in "${!constraint_keys[@]}"; do
        constraints+=("$key=${constraint_keys[$key]}")
    done

    for key in "${!attribute_keys[@]}"; do
        attributes+=("$key=${attribute_keys[$key]}")
    done

    for key in "${!extension_keys[@]}"; do
        extensions+=("$key=${extension_keys[$key]}")
    done

    local sorted_keys=$(printf "%s\n" "${constraints[@]}" | sort)
    local sorted_attributes=$(printf "%s\n" "${attributes[@]}" | sort)
    local sorted_extensions=$(printf "%s\n" "${extensions[@]}" | sort)

    export ATTRIBUTES=$(echo -n "${sorted_attributes}" | tr '\n' "$DELIM_KEY")
    export EXTENSIONS=$(echo -n "${sorted_extensions}" | tr '\n' "$DELIM_KEY")
    export KEYS=$(echo -n "${sorted_keys}" | tr '\n' "$DELIM_KEY")
    export NAMESPACE="$namespace"
    export SOURCE="$source"
    export SOURCE_PROVIDER=$(relk_args_get_source_provider "$SOURCE")
    export SOURCE_PATH=$(relk_args_get_source_path "$SOURCE")
    export FORCE_READ="$force_read"
    export FORCE_WRITE="$FORCE_READ"
    export LIST_OPERATION="$list_operation"
    export ALLOW_SHELL="$allow_shell"
    export ENGINE="$engine"

    relk_debug "args_parse() -> source: $SOURCE, namespace: $NAMESPACE, keys: $KEYS, attributes: $ATTRIBUTES"
}

# <private>
# Gets the provider name from a source.
# parameters: 1: source
relk_args_get_source_provider() {
    echo "$1" | cut -d ":" -f 1
}

# <private>
# Gets the source path from a source.
# parameters: 1: source
relk_args_get_source_path() {
    echo "$1" | cut -d ":" -f 2-
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

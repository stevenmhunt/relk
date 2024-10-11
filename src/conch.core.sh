#!/usr/bin/env bash
# Conch Core Library
# Licensed under MIT License

export DELIM_KEY=','
export DELIM_COL='|'

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${__dir}/providers/conch.file.sh

# <private>
# Writes debug messages to STDERR if the $DEBUG variable is set.
# parameters: 1: debug message
conch_debug() {
    if [ "$DEBUG" == "1" ]; then
        echo "[DEBUG] $1" 1>&2
    fi
}

# <private>
# Writes error messages to STDERR.
# parameters: 1: error message
conch_error() {
    echo "[ERROR] $1" 1>&2
}

# <private>
# Handles the specified error code.
# parameters: 1: error code
conch_handle_error() {
    CODE="$1"
    if [ "$CODE" == "1" ]; then
        conch_error "Unknown command. Usage: conch <command> <...flags>"
        exit 1
    elif [ "$CODE" == "2" ]; then
        conch_error "Unknown source provider."
        exit 2
    elif [ "$CODE" == "3" ]; then
        conch_error "An entry for the requested key with the same constraints already exists. Use the -f flag to overwrite this value."
        exit 3
    elif [ "$CODE" == "4" ]; then
        conch_error "No matching value could be found for the requested key with the provided constraints."
        exit 4
    elif [ "$CODE" == "5" ]; then
        conch_error "An IO error occurred when attempting to read or write to the requested source provider."
        exit 4
    else
        exit "$CODE"
    fi
}

# <private>
# Parses command-line arguments where a <key> is present.
# parameters: <args...>
conch_parse_key_args() {
    shift 1
    export KEY=$1
    conch_parse_args "$@"
}

# <private>
# Parses command-line arguments.
# parameters: <args...>
conch_parse_args() {
    shift 1
    args=( "$@" )
    args+=( $(conch_get_context) )

    export VALUE="$1"
    export VALUE_TYPE="s"
    export DEBUG=$(conch_get_debug "${args[@]}")
    export KEYS=$(conch_get_constraint_keys "${args[@]}")
    export NAMESPACE=$(conch_get_namespace "${args[@]}")
    export SOURCE=$(conch_get_source "${args[@]}")
    export IS_FORCED=$(conch_get_is_forced "${args[@]}")

    # handle template type.
    if [ "$1" == "-t" ]; then
        VALUE="$2"
        VALUE_TYPE="t"
    elif [ "$1" == "-l" ]; then
        VALUE="$2"
        VALUE_TYPE="l"
    fi
}

# <private>
# Calls the specified provider function.
# parameters 1: provider, 2: command, ...arguments
conch_provider_call() {
    CMD="conch_${1}_${2}"

    if typeset -f $CMD > /dev/null; then
        $CMD "${@:3}" || conch_handle_error "$?"
    else
        conch_handle_error "2"
    fi
}

# <private>
# Evaluates the specified template and outputs the result.
# parameters: 1: source, 2: namespace, 3: value
conch_evaluate_template() {
    SOURCE=$1
    NAMESPACE=$2
    VALUE=$3

    TEMPLATE=$(conch_get_template "$SOURCE" "$NAMESPACE" "$VALUE") || exit

    conch_debug "evaluate_template():"
    conch_debug "$TEMPLATE"

    eval "$TEMPLATE"
}

# <private>
# Outputs the expected command text for later execution.
# parameters: 1: command
conch_process_template_command() {
    CMD="$1"
    # check if the command is a sed command
    if [[ "$CMD" == s/* ]]; then    
        echo "sed -E \"$CMD\""
    # otherwise, just return the command as-is.
    else
        echo "$CMD"
    fi
}

# <private>
# Converts a template value to an executable script.
# parameters: 1: source, 2: namespace, 3: value
conch_get_template() {
    local SOURCE=$1
    local NAMESPACE=$2
    local VALUE=$3

    conch_debug "get_template() namespace: $NAMESPACE value: $VALUE"

    local PROVIDER=$(conch_get_source_provider $SOURCE)
    local SOURCE_PATH=$(conch_get_source_path $SOURCE)
    local VAR_KEYS=$(echo "$VALUE" | grep -oE "\{[^}]+\}" | sed 's/[{}]//g')

    echo "#!/usr/bin/env bash"

    local NEW_VALUE=$"$VALUE"
    local VAR_COUNT=0
    while IFS= read -r VAR_KEY; do
        # check if the variable reference contains a command
        if [[ "$VAR_KEY" == *":"* ]]; then
            VAR_KEY_REF=$(echo "$VAR_KEY" | cut -d ":" -f 1)
            VAR_CMD_VALUE=$(echo "$VAR_KEY" | cut -d ":" -f 2-)
            VAR_KEY_VAL=$(conch_get_key "$VAR_KEY_REF") || exit
            VAR_KEY_VALUE=$(printf '%q' "$VAR_KEY_VAL") || exit
            CMD_VALUE=$(conch_process_template_command "$VAR_CMD_VALUE")
            # handle empty string case.
            if [ "$VAR_KEY_VALUE" == "''" ]; then
                VAR_KEY_VALUE=""
            fi
            VAR_VALUE="\$(echo \"$VAR_KEY_VALUE\" | $CMD_VALUE)"
        # check if the variable reference is an external reference
        elif [[ "$VAR_KEY" == \$* ]]; then
            VAR_VALUE="\$(echo \"$VAR_KEY\")"
        # otherwise process normally if the key is present
        elif [ -n "$VAR_KEY" ]; then
            VAR_VAL=$(conch_get_key "$VAR_KEY") || exit
            VAR_VALUE=$(printf '%q' "$VAR_VAL") || exit
            # handle empty string case.
            if [ "$VAR_VALUE" == "''" ]; then
                VAR_VALUE=""
            fi
            VAR_VALUE="\"$VAR_VALUE\""
        fi
        echo "VAR${VAR_COUNT}=$VAR_VALUE"
        ESCAPED_VAR_KEY=$(echo -n "{$VAR_KEY}" | sed -E 's/[]\/$*.^[]/\\&/g') || exit;
        NEW_VALUE=$(echo "$NEW_VALUE" | sed -e "s${DELIM_COL}${ESCAPED_VAR_KEY}${DELIM_COL}\${VAR${VAR_COUNT}}${DELIM_COL}g") || exit
        ((VAR_COUNT++))
    done <<< "$VAR_KEYS"

    echo "echo \"$NEW_VALUE\""
}

# <private>
# Given a key, dependent keys, namespace, etc. returns a key value.
# parameters: 1: $KEYNAME
# variables: $KEYS, $NAMESPACE, $SOURCE
conch_get_key() {
    KEYNAME="${1}"
    PROVIDER=$(conch_get_source_provider $SOURCE)
    SOURCE_PATH=$(conch_get_source_path $SOURCE)

    if [[ -z "$KEYNAME" ]]; then
        conch_error "No matching value could be found for the key '$KEYNAME'."
        exit 4
    fi

    conch_debug "get_key() keyname: $KEYNAME, constraints: ${KEYS[@]}"

    VALUE=$(conch_provider_call $PROVIDER 'get_key_value' "$SOURCE_PATH" "$NAMESPACE" "$KEYNAME" "$KEYS") || exit
    RESULT_TYPE=$(conch_provider_call $PROVIDER 'get_key_value_type' "$SOURCE_PATH" "$NAMESPACE" "$KEYNAME" "$KEYS") || exit

    conch_debug "get_key() -> $KEYNAME = $VALUE ($RESULT_TYPE)"

    if [ "$RESULT_TYPE" == "t" ]; then
        conch_evaluate_template "$SOURCE" "$NAMESPACE" "$VALUE"
    else
        echo "$VALUE"
    fi
}

# <private>
# Streams lines from stdin and evaluates them as templates.
# variables: $KEYS, $NAMESPACE, $SOURCE
conch_in() {
    if [[ -p /dev/stdin ]]; then
        # read lines from stdin if available.
        while IFS= read -r line || [[ -n "$line" ]]; do
            conch_evaluate_template "$SOURCE" "$NAMESPACE" "$line"
        done
    fi
}

# <private>
# Given a key, dependent keys, namespace, etc. sets a key value.
# variables: $KEY, $KEYS, $NAMESPACE, $SOURCE
conch_set_key() {
    PROVIDER=$(conch_get_source_provider $SOURCE)
    SOURCE_PATH=$(conch_get_source_path $SOURCE)
    conch_provider_call $PROVIDER 'set_key_value' "$SOURCE_PATH" "$NAMESPACE" "$KEY" "$VALUE" "$VALUE_TYPE" "$KEYS" "$IS_FORCED"
}

# <private>
# Gets a list of keys.
# variables: $NAMESPACE, $SOURCE
conch_get_keys() {
    PROVIDER=$(conch_get_source_provider $SOURCE)
    SOURCE_PATH=$(conch_get_source_path $SOURCE)
    conch_provider_call $PROVIDER 'get_all_keys' "$SOURCE_PATH" "$NAMESPACE"
}

# <private>
# Gets the provider name from a source.
conch_get_source_provider() {
    echo "$1" | cut -d ":" -f 1
}

# <provider>
# Gets the source path from a source.
conch_get_source_path() {
    echo "$1" | cut -d ":" -f 2-
}

# <private>
# Extracts the constraint keys from arguments.
conch_get_constraint_keys() {
    args=("$@")
    declare -A keys_dict

    # Loop through all arguments and check for the "-k" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-k" && $((i+1)) -lt ${#args[@]} ]]; then
            key_value="${args[$((i+1))]}"
            key="${key_value%%=*}"
            value="${key_value#*=}"
            keys_dict["$key"]="$value"
            conch_debug "get_constraint_keys() $key = $value"
        fi
    done

    # Convert the associative array back to a normal array
    keys=()
    for key in "${!keys_dict[@]}"; do
        keys+=("$key=${keys_dict[$key]}")
    done

    # Sort the keys
    sorted_keys=$(printf "%s\n" "${keys[@]}" | sort)

    echo -n "${sorted_keys}" | tr '\n' "$DELIM_KEY"
}

# <private>
# Extracts the namespace from arguments.
conch_get_namespace() {
    args=("$@")
    namespace="default"

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
conch_get_source() {
    args=("$@")
    source="file:$HOME/.conchfile"

    # Loop through all arguments to find the last "-s" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-s" && $((i+1)) -lt ${#args[@]} ]]; then
            source="${args[$((i+1))]}"  # Update the source with the last occurrence
            break
        fi
    done

    # Output the last found source value
    echo -n "$source"
}

# <private>
# Extracts the IS_FORCED flag from arguments.
conch_get_is_forced() {
    args=("$@")
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
conch_get_debug() {
    # check if the DEBUG variable is already set.
    if [ "$DEBUG" == "1" ]; then
        echo "1"
        return
    fi

    # Loop through all the arguments to check for the "--debug" flag
    args=("$@")
    for arg in "${args[@]}"; do
        if [[ "$arg" == "--debug" ]]; then
            echo "1"
            return
        fi
    done

    echo "0"
}

# <private>
# Gets the context from the .conch file and parent directories.
conch_get_context() {
    context_file=".conch"
    result=""

    # Function to read and append content from .conch files
    append_context_file() {
        local file="$1"
        if [ -f "$file" ]; then
            result+=$(cat "$file")
            result+=$'\n'
        fi
    }

    # Start from the current directory and move up through parent directories
    dir="$PWD"
    while [ "$dir" != "/" ]; do
        append_context_file "$dir/$context_file"
        dir=$(dirname "$dir")
    done

    # Check for ~/.conch
    append_context_file "$HOME/$context_file"

    echo -n "$result"
}

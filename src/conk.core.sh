#!/bin/bash

export DELIM_KEY=','
export DELIM_COL='|'

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source ${__dir}/providers/conk.file.sh

conk_debug() {
    if [ "$DEBUG" == "true" ]; then
        echo "[DEBUG] $1" 1>&2
    fi
}

conk_error() {
    echo "[ERROR] $1" 1>&2
}

# <private>
conk_parse_args() {
    shift 1
    export KEY=$1
    shift 1
    args=( "$@" )
    args+=( $(conk_get_context) )

    export VALUE="$1"
    export VALUE_TYPE="s"
    export DEBUG=$(conk_get_debug "${args[@]}")
    export KEYS=$(conk_get_constraint_keys "${args[@]}")
    export NAMESPACE=$(conk_get_namespace "${args[@]}")
    export SOURCE=$(conk_get_source "${args[@]}")
    export IS_FORCED=$(conk_get_is_forced "${args[@]}")

    conk_debug "parse_args() keys: ${KEYS}"

    if [ "$1" == "-t" ]; then
        VALUE="$2"
        VALUE_TYPE="t"
    elif [ "$1" == "-l" ]; then
        VALUE="$2"
        VALUE_TYPE="l"
    fi
}

conk_execute_command() {
    CMD="conk_${1}_${2}"

    if typeset -f $CMD > /dev/null; then
        $CMD "${@:3}" || exit "$?"
    else
        conk_error "Unknown source provider ${1}."
        exit 2
    fi
}

conk_execute_template() {
    SOURCE=$1
    NAMESPACE=$2
    VALUE=$3

    conk_debug "process_template() $VALUE"

    #conk_get_template $SOURCE $NAMESPACE $VALUE
    TEMPLATE=$(conk_get_template "$SOURCE" "$NAMESPACE" "$VALUE") || exit

    conk_debug "process_template():"
    conk_debug "$TEMPLATE"

    eval "$TEMPLATE"
}

conk_process_template_command() {
    CMD="$1"
    # check if the command is a sed command
    if [[ "$CMD" == s/* ]]; then    
        echo "sed -E \"$CMD\""
    # otherwise, just return the command as-is.
    else
        echo "$CMD"
    fi
}

conk_get_template() {
    local SOURCE=$1
    localNAMESPACE=$2
    localVALUE=$3

    conk_debug "get_template() namespace: $NAMESPACE value: $VALUE"

    local PROVIDER=$(conk_get_source_provider $SOURCE)
    local SOURCE_PATH=$(conk_get_source_path $SOURCE)
    local VAR_KEYS=$(echo "$VALUE" | grep -oE "\{[^}]+\}" | sed 's/[{}]//g')

    echo "#!/bin/bash"

    local NEW_VALUE=$"$VALUE"
    local VAR_COUNT=0
    while IFS= read -r VAR_KEY; do
        if [[ "$VAR_KEY" == *":"* ]]; then
            VAR_KEY_REF=$(echo "$VAR_KEY" | cut -d ":" -f 1)
            VAR_CMD_VALUE=$(echo "$VAR_KEY" | cut -d ":" -f 2-)
            VAR_KEY_VAL=$(conk_get_key "$VAR_KEY_REF") || exit
            VAR_KEY_VALUE=$(printf '%q' "$VAR_KEY_VAL") || exit
            CMD_VALUE=$(conk_process_template_command "$VAR_CMD_VALUE")
            VAR_VALUE="\$(echo \"$VAR_KEY_VALUE\" | $CMD_VALUE)"

        elif [ -n "$VAR_KEY" ]; then
            VAR_VAL=$(conk_get_key "$VAR_KEY") || exit
            VAR_VALUE=$(printf '%q' "$VAR_VAL") || exit
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
# parameters: $KEY, $KEYS, $NAMESPACE, $SOURCE
conk_get_key() {
    KEYNAME="${1}"
    PROVIDER=$(conk_get_source_provider $SOURCE)
    SOURCE_PATH=$(conk_get_source_path $SOURCE)

    if [[ -z "$KEYNAME" ]]; then
        conk_error "No matching value could be found for the key '$KEYNAME'."
        exit 4
    fi

    conk_debug "get_key() keyname: $KEYNAME, constraints: ${KEYS[@]}"

    VALUE=$(conk_execute_command $PROVIDER 'get_key_value' "$SOURCE_PATH" "$KEYNAME") || exit
    RESULT_TYPE=$(conk_execute_command $PROVIDER 'get_key_value_type' "$SOURCE_PATH" "$KEYNAME") || exit

    conk_debug "get_key() -> $KEYNAME = $VALUE ($RESULT_TYPE)"

    if [ "$RESULT_TYPE" == "t" ]; then
        conk_execute_template "$SOURCE" "$NAMESPACE" "$VALUE"
    else
        echo "$VALUE"
    fi
}

# <private>
# Given a key, dependent keys, namespace, etc. sets a key value.
# parameters: $KEY, $KEYS, $NAMESPACE, $SOURCE
conk_set_key() {
    PROVIDER=$(conk_get_source_provider $SOURCE)
    SOURCE_PATH=$(conk_get_source_path $SOURCE)
    conk_execute_command $PROVIDER 'set_key' $SOURCE_PATH
}

conk_get_keys() {
    PROVIDER=$(conk_get_source_provider $SOURCE)
    SOURCE_PATH=$(conk_get_source_path $SOURCE)
    conk_execute_command $PROVIDER 'get_all_keys' $SOURCE_PATH
}

conk_get_source_provider() {
    echo "$1" | cut -d ":" -f 1
}

conk_get_source_path() {
    echo "$1" | cut -d ":" -f 2-
}

conk_get_constraint_keys() {
    args=("$@")
    declare -A keys_dict

    # Loop through all arguments and check for the "-k" flag
    for (( i=0; i<${#args[@]}; i++ )); do
        if [[ "${args[$i]}" == "-k" && $((i+1)) -lt ${#args[@]} ]]; then
            key_value="${args[$((i+1))]}"
            key="${key_value%%=*}"
            value="${key_value#*=}"
            keys_dict["$key"]="$value"
            conk_debug "get_constraint_keys() $key = $value"
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
conk_get_namespace() {
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
conk_get_source() {
    args=("$@")
    source="file:$HOME/.conkfile"

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
conk_get_is_forced() {
    args=("$@")
    # Loop through all the arguments to check for the "-f" flag
    for arg in "${args[@]}"; do
        if [[ "$arg" == "-f" ]]; then
            echo "true"
            return
        fi
    done
    echo "false"
}

# <private>
conk_get_debug() {
    args=("$@")
    # Loop through all the arguments to check for the "--debug" flag
    for arg in "${args[@]}"; do
        if [[ "$arg" == "--debug" ]]; then
            echo "true"
            return
        fi
    done
    echo "false"
}

# <private>
conk_get_context() {
    context_file=".conk"
    result=""

    # Function to read and append content from .conk files
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

    # Check for ~/.conk
    append_context_file "$HOME/$context_file"

    echo -n "$result"
}

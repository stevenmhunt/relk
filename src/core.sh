################################
# Relk Core Library
# Licensed under MIT License
################################

# <private>
# Writes debug messages to STDERR if the $DEBUG variable is set.
# parameters: 1: debug message
relk_debug() {
    if [ "$DEBUG" == "1" ]; then
        echo "[DEBUG] $1" 1>&2
    fi
}

# <private>
# Writes error messages to STDERR.
# parameters: 1: error message
relk_error() {
    echo "[ERROR] $1" 1>&2
}

# <private>
# Handles the specified error code.
# parameters: 1: error code
relk_handle_error() {
    relk_debug "Exiting with error code $1..."
    local error_code="$1"
    if [ "$error_code" == "1" ]; then
        relk_error "Unknown command. Usage: relk <command> <...flags>"
        exit 1
    elif [ "$error_code" == "2" ]; then
        relk_error "Unknown source provider."
        exit 2
    elif [ "$error_code" == "3" ]; then
        relk_error "An entry for the requested key with the same constraints already exists. Use the -f flag to overwrite this value."
        exit 3
    elif [ "$error_code" == "4" ]; then
        relk_error "No matching value could be found for the requested key with the provided constraints."
        exit 4
    elif [ "$error_code" == "5" ]; then
        relk_error "An IO error occurred when attempting to read or write to the requested source provider."
        exit 5
    else
        exit "$error_code"
    fi
}

# <private>
# Parses command-line arguments where a <key> is present.
# parameters: <args...>
# exports: $KEY
relk_parse_key_args() {
    shift 1
    export KEY=$1
    relk_parse_args "$@"
}

# <private>
# Parses command-line arguments.
# parameters: <args...>
# exports: $VALUE, $VALUE_TYPE, $DEBUG, $KEYS, $NAMESPACE, $SOURCE, $SOURCE_PROVIDER, $SOURCE_PATH, $FORCE_READ, $FORCE_WRITE
relk_parse_args() {
    shift 1
    local args
    args=( $(relk_get_context) )
    args+=( "$@" )

    relk_debug "parse_args() args: $@"

    export VALUE="$1"
    export VALUE_TYPE="s"
    export DEBUG=$(relk_get_debug "${args[@]}")
    export KEYS=$(relk_get_constraint_keys "${args[@]}")
    export NAMESPACE=$(relk_get_namespace "${args[@]}")
    export SOURCE=$(relk_get_source "${args[@]}")
    export SOURCE_PROVIDER=$(relk_get_source_provider $SOURCE)
    export SOURCE_PATH=$(relk_get_source_path $SOURCE)
    export FORCE_READ=$(relk_get_force "${args[@]}")
    export FORCE_WRITE="$FORCE_READ"

    # handle template type.
    if [ "$1" == "-t" ]; then
        VALUE="$2"
        VALUE_TYPE="t"
    elif [ "$1" == "-l" ]; then
        VALUE="$2"
        VALUE_TYPE="l"
    fi

    relk_debug "parse_args() -> source: $SOURCE, namespace: $NAMESPACE, keys: $KEYS"
}

# <private>
# Calls the specified provider function.
# parameters 1: provider, 2: command, ...arguments
relk_provider_call() {
    local command="relk_provider_$1_$2"

    if typeset -f $command > /dev/null; then
        $command "${@:3}" || relk_handle_error "$?"
    else
        relk_handle_error "2"
    fi
}

# <private>
# Evaluates the specified template and outputs the result.
# parameters: 1: source, 2: namespace, 3: value
relk_evaluate_template() {
    local source=$1
    local namespace=$2
    local value=$3

    local template
    template=$(relk_get_template "$source" "$namespace" "$value") || exit

    relk_debug "evaluate_template():"
    relk_debug "-------------------------------------------------------"
    relk_debug "$template"
    relk_debug "-------------------------------------------------------"

    eval "$template"
}

# <private>
# Converts a template value to an executable script.
# parameters: 1: source, 2: namespace, 3: value
relk_get_template() {
    local source=$1
    local namespace=$2
    local value=$3

    local var_keys=$(echo "$value" | grep -oE "\{[^}]+\}" | sed 's/[{}]//g')
    relk_debug "get_template() namespace: $namespace, value: $value"

    echo "#!/usr/bin/env bash"

    local result_value=$"$value"
    local varname_count=0
    local list_vars=()
    local var_declarations=()
    declare -A key_var_mapping
    
    # <private>
    # Processes a token.
    # parameters: 1: token
    # exports: $PROCESSED_TOKEN
    internal_process_token() {
        local token="$1"
        export PROCESSED_TOKEN="$token"

        # string literal
        if [[ -n "$token" && $token == \'* ]]; then
            PROCESSED_TOKEN="$token"

        # number literal
        elif [[ "$token" =~ ^[0-9] ]]; then
            PROCESSED_TOKEN="$token"

        # reference to current value
        elif [[ "$token" == "this" ]]; then
            PROCESSED_TOKEN="\$this"

        # variable reference
        elif [[ "$token" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            internal_process_variable_key "$token" "1"
            PROCESSED_TOKEN="\$$VARIABLE_NAME"
        fi
    }

    # <private>
    # Processes a conditional template expression.
    # parameters: 1: conditional
    # exports: $TEMPLATE_COMMAND
    internal_process_template_conditional() {
        local conditional="$1"

        relk_debug "_process_template_conditional() conditional: $conditional"

        local conditions=$(echo "$conditional" | cut -d ":" -f 2- | sed 's/ and / && /g' | sed 's/ or / || /g')
        local tokens=$(relk_util_tokenize "$conditions")
        local condition_expression=""
        while IFS= read -r token; do
            internal_process_token "$token"
            condition_expression+=" $PROCESSED_TOKEN"
        done <<< "$tokens"
        condition_expression+=" "

        export TEMPLATE_COMMAND="(while IFS= read -r this; do [[$condition_expression]] && echo "\$this"; done)"
    }

    # <private>
    # Processes a default template expression.
    # parameters: 1: default
    # exports: $TEMPLATE_COMMAND
    internal_process_template_default() {
        local default="$1"
        local condition_expression=" -z \"\$this\" "

        internal_process_token "$default"
        export TEMPLATE_COMMAND="(while IFS= read -r this; do [[$condition_expression]] && echo "$PROCESSED_TOKEN" || echo "\$this"; done)"

        relk_debug "_process_template_default() default: $default"
    }

    # <private>
    # Processes a command template expression.
    # parameters: 1: command
    # exports: $TEMPLATE_COMMAND
    internal_process_template_command() {
        local command="$1"
        export TEMPLATE_COMMAND="$command"

        relk_debug "_process_template_command() command: $command"
    }

    # <private>
    # Processes a sedvcommand template expression.
    # parameters: 1: command
    # exports: $TEMPLATE_COMMAND
    internal_process_template_sed_command() {
        local command="$1"
        export TEMPLATE_COMMAND="sed -E \"$command\""

        relk_debug "_process_template_sed_command() command: $command"
    }

    # <private>
    # Processes a variable key.
    # parameters: 1: key
    # imports: $FORCE_READ
    # exports: $VARIABLE_NAME
    internal_process_variable_key() {
        local var_key="$1"
        local force_read="0"
        if [[ "$FORCE_READ" == 1 || "$2" == 1 ]]; then
            force_read="1"
        fi

        local var_key_type="s"
        local var_value=""

        relk_debug "_process_variable_key(): $var_key"

        # skip processing if the variable was already processed.
        if [[ -n "$var_key" && -n "${key_var_mapping["$var_key"]}" ]]; then
            export VARIABLE_NAME="${key_var_mapping["$var_key"]}"
            return

        # check if the variable reference contains a command or conditional
        elif [[ "$var_key" == *":"* ]]; then
            local var_key_ref=$(echo "$var_key" | cut -d ":" -f 1)
            local var_command=$(echo "$var_key" | cut -d ":" -f 2-)

            # check if the command is a conditional
            if [[ "$var_command" == "?"* ]]; then
                var_command=$(echo "$var_command" | cut -d "?" -f 2-)
                internal_process_template_conditional "$var_command"
            
            # check if the command is a sed command
            elif [[ "$var_command" == "#"* ]]; then
                var_command=$(echo "$var_command" | cut -d "#" -f 2-)
                internal_process_template_sed_command "$var_command"

            # check if the command is a default
            elif [[ "$var_command" == "="* ]]; then
                var_command=$(echo "$var_command" | cut -d "=" -f 2-)
                internal_process_template_default "$var_command"

            # check if the command is a pipe command
            elif [[ "$var_command" == "|"* ]]; then
                var_command=$(echo "$var_command" | cut -d "|" -f 2-)
                internal_process_template_command "$var_command"

            # otherwise process as a command
            else
                internal_process_template_command "$var_command"
            fi

            # check for an external variable reference
            if [[ "$var_key_ref" == \$* ]]; then
                var_value="\$(echo \"$var_key_ref\" | $TEMPLATE_COMMAND)"

            # otherwise, build the variable reference
            else
                local var_key_result
                var_key_result=$(relk_get_key "$var_key_ref" "$force_read" "1") || exit

                local var_key_val
                var_key_val=$(echo "$var_key_result" | cut -d "$DELIM_COL" -f 1)

                local var_key_value
                var_key_value=$(relk_util_escape "$var_key_val")

                var_value=$(while IFS= read -r line; do
                    echo "\$(echo \"$line\" | $TEMPLATE_COMMAND)"
                done <<< "$var_key_value")
                var_key_type=$(echo "$var_key_result" | cut -d "$DELIM_COL" -f 2)            
            fi

        # check if the variable reference is an external reference
        elif [[ "$var_key" == \$* ]]; then
            var_value="\$(echo \"$var_key\")"

        # otherwise process normally if the key is present
        elif [ -n "$var_key" ]; then
            local var_key_result
            var_key_result=$(relk_get_key "$var_key" "$force_read" "1") || exit

            local var_key_value
            var_key_value=$(echo "$var_key_result" | cut -d "$DELIM_COL" -f 1)

            var_value=$(relk_util_escape "$var_key_value")
            var_key_type=$(echo "$var_key_result" | cut -d "$DELIM_COL" -f 2)

            # build the variable reference
            var_value=$(while IFS= read -r line; do
                echo "\"$line\""
            done <<< "$var_value")

        else
            return
        fi

        local var_name="VAR${varname_count}"

        # if there are multiple values or the key is a list, generate a loop.
        local value_count=0
        if [ -n "$var_value" ]; then
            value_count=$(echo "$var_value" | wc -l)
        fi

        relk_debug "${var_name} ($var_key_type) = $var_value"

        # for list data, build an array and iterate through it.
        if [ "$value_count" -gt "1" ] || [ "$var_key_type" = "l" ]; then
            var_declarations+=("LIST_$var_name=()")
            while IFS= read -r var_element; do
                if [ "$var_element" != "\"\"" ]; then
                    var_declarations+=("LIST_$var_name+=($var_element)")
                fi
            done <<< "$var_value"
            var_declarations+=("for $var_name in \"\${LIST_$var_name[@]}\"; do")
            list_vars+=("LIST_$var_name")

        # otherwise, just set the value.
        else
            var_declarations+=("$var_name=$var_value")
        fi
        key_var_mapping["$var_key"]="$var_name"

        local escaped_var_key
        escaped_var_key=$(echo -n "{$var_key}" | sed -E 's/[]\/$*.^[]/\\&/g') || exit;
        result_value=$(echo "$result_value" | sed -e "s${DELIM_COL}${escaped_var_key}${DELIM_COL}\${$var_name}${DELIM_COL}g") || exit
        ((varname_count++))
        export VARIABLE_NAME="$var_name"
    }

    # iterate through all known variable references.
    while IFS= read -r var_key; do
        internal_process_variable_key "$var_key"
    done <<< "$var_keys"

    # print out the variable declarations.
    printf '%s\n' "${var_declarations[@]}"

    # print the template expression.
    echo "echo \"$result_value\""

    # close any list value loops
    local list_count="${#list_vars[@]}"
    for (( i=list_count-1; i>=0; i-- )); do
        echo "done"
    done
}

declare -a relk_key_stack

# <private>
# Given a key, dependent keys, namespace, etc. returns a key value.
# parameters: 1: key name, force read (1 or 0), 2: include type? (1 or 0)
# imports: $KEYS, $NAMESPACE, $SOURCE_PROVIDER, $SOURCE_PATH
relk_get_key() {
    local key_name="$1"
    local force_read="$2"
    local include_type="$3"

    if [[ -z "$key_name" ]]; then
        relk_error "No matching value could be found for the key '$key_name'."
        return 4
    fi

    relk_debug "get_key() key name: $key_name, constraints: ${KEYS[@]}"

    # cycle detection code.
    for stack_key in "${relk_key_stack[@]}"; do
        if [[ "$stack_key" == "$key_name" ]]; then
            relk_debug "WARNING: Cycle detected for key: $key_name"
            if [ "$include_type" = "1" ]; then
                echo -n "|s"
            else
                echo -n ""
            fi
            return 0
        fi
    done
    relk_key_stack+=("$key_name")

    local value_data
    value_data=$(relk_provider_call "$SOURCE_PROVIDER" 'get_key_value' "$SOURCE_PATH" "$NAMESPACE" "$key_name" "$KEYS" "$force_read") || exit

    local value
    value=$(echo "$value_data" | cut -d "$DELIM_COL" -f 1)

    local value_type
    value_type=$(echo "$value_data" | cut -d "$DELIM_COL" -f 2)

    local type_data=""
    if [ "$include_type" = "1" ]; then
        type_data="|${value_type}"
    fi

    relk_debug "get_key() -> $key_name = $value ($value_type)"

    # handle template type.
    if [ "$value_type" == "t" ]; then
        relk_evaluate_template "$SOURCE" "$NAMESPACE" "$value"

    # handle list type.
    elif [ "$value_type" == "l" ]; then
        echo "$value${type_data}" | tr ',' '\n'

    # handle string type.
    else
        echo "$value${type_data}"
    fi

    # pop the cycle detection stack.
    relk_key_stack=("${relk_key_stack[@]::$((${#relk_key_stack[@]}-1))}")
}

# <private>
# Streams lines from stdin and evaluates them as templates.
# imports: $KEYS, $NAMESPACE, $SOURCE
relk_in() {
    if [[ -p /dev/stdin ]]; then
        # read lines from stdin if available.
        while IFS= read -r line || [[ -n "$line" ]]; do
            relk_evaluate_template "$SOURCE" "$NAMESPACE" "$line"
        done
    fi
}

# <private>
# Given a key, dependent keys, namespace, etc. sets a key value.
# imports: $KEY, $KEYS, $NAMESPACE, $SOURCE
relk_set_key() {
    relk_provider_call "$SOURCE_PROVIDER" 'set_key_value' "$SOURCE_PATH" "$NAMESPACE" "$KEY" "$VALUE" "$VALUE_TYPE" "$KEYS" "$FORCE_WRITE"
}

# <private>
# Gets a list of keys.
# imports: $NAMESPACE, $SOURCE
relk_get_keys() {
    relk_provider_call "$SOURCE_PROVIDER" 'get_all_keys' "$SOURCE_PATH" "$NAMESPACE"
}

# <private>
# Gets the provider name from a source.
# parameters: 1: source
relk_get_source_provider() {
    echo "$1" | cut -d ":" -f 1
}

# <provider>
# Gets the source path from a source.
# parameters: 1: source
relk_get_source_path() {
    echo "$1" | cut -d ":" -f 2-
}

# <private>
# Extracts the constraint keys from arguments.
# parameters: ...args
relk_get_constraint_keys() {
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
# Extracts the namespace from arguments.
# parameters: ...args
relk_get_namespace() {
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
relk_get_source() {
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
relk_get_force() {
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
relk_get_debug() {
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

################################
# Relk Core Library
# Licensed under MIT License
################################

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

        local conditions=$(echo "$conditional" | sed 's/ and / && /g' | sed 's/ or / || /g')
        local tokens=$(relk_util_tokenize "$conditions")
        local condition_expression=""
        while IFS= read -r token; do
            internal_process_token "$token"
            condition_expression+=" $PROCESSED_TOKEN"
        done <<< "$tokens"
        condition_expression+=" "

        export TEMPLATE_COMMAND="(while IFS= read -r this; do [[$condition_expression]] && echo "\$this" || echo ""; done)"
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
        local command=$(relk_util_unwrap "$1")
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
        fi

        local var_key_ref=$(echo "$var_key" | cut -d "$DELIM_CMD" -f 1)        

        # check if the variable reference is an external reference
        if [[ "$var_key_ref" == \$* ]]; then
            var_value="\"$var_key_ref\""

        # otherwise process normally if the key is present
        elif [ -n "$var_key_ref" ]; then
            local var_key_result
            var_key_result=$(relk_get_key "$var_key_ref" "$force_read" "1") || exit

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

        # check if the variable reference contains commands
        if [[ "$var_key" == *"$DELIM_CMD"* ]]; then
            # iterate through each command
            local var_command=$(echo "$var_key" | cut -d "$DELIM_CMD" -f 2-)

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

            # otherwise process as a command
            else
                internal_process_template_command "$var_command"
            fi

            var_value=$(while IFS= read -r line; do
                    echo "\$(echo $line | $TEMPLATE_COMMAND)"
                done <<< "$var_value")
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
    local hook_result

    hook_result=$(relk_platform_hook 'before_get_key' "$key_name") || exit
    key_name="$hook_result"

    relk_util_validate_key_name "$key_name"

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
    value_data=$(relk_platform_provider_call "$SOURCE_PROVIDER" 'get_key_value' "$SOURCE_PATH" "$NAMESPACE" "$key_name" "$KEYS" "$force_read") || exit

    local value
    value=$(echo "$value_data" | cut -d "$DELIM_COL" -f 1)

    local attributes
    attributes=$(echo "$value_data" | cut -d "$DELIM_COL" -f 2)

    local attribute_data=""
    if [ "$include_type" = "1" ]; then
        attribute_data="|${attributes}"
    fi

    relk_debug "get_key() -> $key_name = $value ($attributes)"

    local result
    local value_type=$(echo "$attributes" | cut -d ',' -f 1)

    # handle template type.    
    if [ "$value_type" == "t" ]; then
        result=$(relk_evaluate_template "$SOURCE" "$NAMESPACE" "$value") || exit

    # handle list type.
    elif [ "$value_type" == "l" ]; then
        result=$(echo "$value" | tr ',' '\n') || exit

    # handle string type.
    else
        result="$value"
    fi

    hook_result=$(relk_platform_hook 'after_get_key' "$result" "$attributes" "$key_name") || exit
    result="$hook_result"

    # output the results.
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "$line$attribute_data"
        fi
    done <<< "$result"

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
    relk_platform_hook 'before_set_key' "$NAMESPACE" "$KEY" "$VALUE" "$VALUE_TYPE" "$ATTRIBUTES" "$KEYS"

    relk_util_validate_key_name "$KEY"
    relk_util_validate_key_value "$VALUE"

    relk_platform_provider_call "$SOURCE_PROVIDER" 'set_key_value' "$SOURCE_PATH" "$NAMESPACE" "$KEY" "$VALUE" "$VALUE_TYPE" "$ATTRIBUTES" "$KEYS" "$FORCE_WRITE"

    relk_platform_hook 'after_set_key' "$NAMESPACE" "$KEY" "$VALUE" "$VALUE_TYPE" "$ATTRIBUTES" "$KEYS"
}

# <private>
# Gets a list of keys.
# imports: $NAMESPACE, $SOURCE
relk_get_keys() {
    relk_platform_provider_call "$SOURCE_PROVIDER" 'get_all_keys' "$SOURCE_PATH" "$NAMESPACE"
}

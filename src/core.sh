################################
# Relk Core Library
# Licensed under MIT License
################################

# <private>
# Evaluates the specified template and outputs the result.
# parameters: 1: source, 2: namespace, 3: value
relk_evaluate_template() {
    local source="$1"
    local namespace="$2"
    local value="$3"

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
    local source="$1"
    local namespace="$2"
    local value="$3"

    local var_keys=$(echo "$value" | grep -oE "\{[^}]+\}" | sed 's/[{}]//g')
    relk_debug "get_template() namespace: $namespace, value: $value"

    echo "#!/usr/bin/env bash"

    local result_value=$(relk_util_escape "$value")
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
        export PROCESSED_TOKEN=""

        # string literal
        if [[ -n "$token" && ($token == "'"* || $token == "\""*) ]]; then
            PROCESSED_TOKEN=$(relk_util_unwrap "$token")

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
        
        else
            PROCESSED_TOKEN=$(relk_util_escape "$token")
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

        export TEMPLATE_COMMAND="(while IFS= read -r this; do [[$condition_expression]] && echo \"\$this\" || echo \"\"; done)"
    }

    # <private>
    # Processes a default template expression.
    # parameters: 1: default
    # exports: $TEMPLATE_COMMAND
    internal_process_template_default() {
        local default="$1"
        local condition_expression=" -z \"\$this\" "

        relk_debug "_process_template_default() default: $default"
        internal_process_token "$default"
        export TEMPLATE_COMMAND="(while IFS= read -r this; do [[$condition_expression]] && echo \"$PROCESSED_TOKEN\" || echo \"\$this\"; done)"

        relk_debug "_process_template_default() command: $TEMPLATE_COMMAND"
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
        if [[ "$var_key_ref" == \$* && "$var_key_ref" != *' '* && "$var_key_ref" != *\$ ]]; then
            var_value="\"$var_key_ref\""

        # otherwise process normally if the key is present
        elif [ -n "$var_key_ref" ]; then
            local var_key_result
            var_key_result=$(relk_get_key "$var_key_ref" "$force_read" "0") || exit
            relk_debug "_process_variable_key(): var_key_result: $var_key_result"

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
                if [ "$ALLOW_SHELL" != "1" ]; then
                    relk_handle_error "8"
                fi
                var_command=$(echo "$var_command" | cut -d "?" -f 2-)
                internal_process_template_conditional "$var_command"
            
            # check if the command is a sed command
            elif [[ "$var_command" == "#"* ]]; then
                var_command=$(echo "$var_command" | cut -d "#" -f 2-)
                internal_process_template_sed_command "$var_command"

            # check if the command is a default
            elif [[ "$var_command" == "="* ]]; then
                var_command=$(echo "$var_command" | cut -d "=" -f 2-)
                relk_debug "DEFAULT var_command: $var_command"
                internal_process_template_default "$var_command"

            # otherwise process as a command
            else
                if [ "$ALLOW_SHELL" != "1" ]; then
                    relk_handle_error "8"
                fi
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
        var_key=$(relk_util_escape "$var_key")
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

# <private>
# Given a key, dependent keys, namespace, etc. returns the attributes.
# parameters: 1: key name, 2: force read (1 or 0)
# imports: $KEYS, $NAMESPACE, $SOURCE_PROVIDER, $SOURCE_PATH
relk_get_attributes() {
    local key_name="$1"
    local force_read="$2"

    local value_data
    value_data=$(relk_platform_provider_call "$SOURCE_PROVIDER" 'get_key_value' "$SOURCE_PATH" "$NAMESPACE" "$key_name" "$KEYS" "$force_read") || exit

    local attributes
    attributes=$(echo "$value_data" | cut -d "$DELIM_COL" -f 3)

    if [ -z "$attributes" ]; then
        relk_debug "get_attributes() -> $key_name (none)"
        echo -n ""
        return
    fi

    relk_debug "get_attributes() -> $key_name [$attributes]"
    echo "$attributes" | tr ',' '\n'
}

declare -a relk_key_stack

# <private>
# Given a key, dependent keys, namespace, etc. returns a key value.
# parameters: 1: key name, force read (1 or 0), 2: is top-level call? (1 or 0)
# imports: $KEYS, $NAMESPACE, $SOURCE_PROVIDER, $SOURCE_PATH
relk_get_key() {
    local key_name="$1"
    local force_read="$2"
    local is_top_level="$3"
    local hook_result
    local key_constraints="$KEYS"

    hook_result=$(relk_platform_hook 'before_get_key' "$key_name|$key_constraints" "$is_top_level") || exit
    key_name=$(echo "$hook_result" | cut -d '|' -f 1)
    key_constraints=$(echo "$hook_result" | cut -d '|' -f 2)

    relk_util_validate_key_name "$key_name"

    if [[ -z "$key_name" ]]; then
        return 4
    fi

    relk_debug "get_key() key name: $key_name, constraints: ${KEYS[@]}"

    # cycle detection code.
    for stack_key in "${relk_key_stack[@]}"; do
        if [[ "$stack_key" == "$key_name" ]]; then
            relk_debug "WARNING: Cycle detected for key: $key_name"
            if [ "$is_top_level" = "0" ]; then
                echo -n "|s"
            else
                echo -n ""
            fi
            return 0
        fi
    done
    relk_key_stack+=("$key_name")

    local value_data
    value_data=$(relk_platform_provider_call "$SOURCE_PROVIDER" 'get_key_value' "$SOURCE_PATH" "$NAMESPACE" "$key_name" "$key_constraints" "$force_read") || exit

    local key_value
    local value_type
    local attributes
    key_value=$(echo "$value_data" | cut -d "$DELIM_COL" -f 1)
    value_type=$(echo "$value_data" | cut -d "$DELIM_COL" -f 2)
    attributes=$(echo "$value_data" | cut -d "$DELIM_COL" -f 3)

    relk_debug "get_key() -> $key_name = $key_value ($value_type) [$attributes]"

    # handle template type.    
    if [ "$value_type" == "t" ]; then
        key_value=$(relk_evaluate_template "$SOURCE" "$NAMESPACE" "$key_value") || exit

    # handle list type.
    elif [ "$value_type" == "l" ]; then
        key_value=$(echo "$key_value" | tr ',' '\n') || exit
    fi

    key_value=$(relk_platform_hook 'after_get_key' "$key_value" "$key_name" "$value_type" "$attributes" "$is_top_level") || exit

    local attribute_data=""
    if [ "$is_top_level" = "0" ]; then
        attribute_data="|$value_type|$attributes"
    fi

    # output the results.
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "$line$attribute_data"
        fi
    done <<< "$key_value"

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
    local key_name="$KEY"
    local key_value="$VALUE"
    local force_write="$FORCE_WRITE"
    local value_type
    local attributes
    local key_constraints
    local hook_result

    hook_result=$(relk_platform_hook 'before_set_key' "$key_name|$key_value|$VALUE_TYPE|$ATTRIBUTES|$KEYS") || exit
    key_name=$(echo "$hook_result" | cut -d '|' -f 1)
    key_value=$(echo "$hook_result" | cut -d '|' -f 2)
    value_type=$(echo "$hook_result" | cut -d '|' -f 3)
    attributes=$(echo "$hook_result" | cut -d '|' -f 4)
    key_constraints=$(echo "$hook_result" | cut -d '|' -f 5)

    relk_util_validate_key_name "$KEY"
    relk_util_validate_key_value "$VALUE"

    relk_debug "set_key() -> $key_name ($value_type) [$attributes] = $key_value [$key_constraints]"

    # handle list operations.
    if [ "$value_type" == "l" ]; then
        if [[ "$key_value" = "--remove-all" ]]; then
            force_write=1
            key_value=""
        elif [[ "$key_value" = "--remove"* ]]; then
            LIST_OPERATION="remove"
        fi
        if [ -n "$LIST_OPERATION" ]; then
            force_write=1
            local value_data
            value_data=$(relk_platform_provider_call "$SOURCE_PROVIDER" 'get_key_value' "$SOURCE_PATH" "$NAMESPACE" "$key_name" "$key_constraints" "1") || exit

            local new_key_value
            new_key_value=$(echo "$value_data" | cut -d "$DELIM_COL" -f 1)

            if [ "$LIST_OPERATION" == "remove" ]; then
                if [ -z "$new_key_value" ]; then
                    key_value=""
                elif [ "$key_value" == "--remove-first" ]; then
                    key_value=$(relk_util_list_remove_first "$new_key_value")
                elif [ "$key_value" == "--remove-last" ]; then
                    key_value=$(relk_util_list_remove_last "$new_key_value")
                elif [[ "$key_value" == "--remove-at:"* ]]; then
                    local index=$(echo "$key_value" | cut -d ':' -f 2)
                    key_value=$(relk_util_list_remove_at "$new_key_value" "$index")
                elif [[ "$key_value" == "--remove:"* ]]; then
                    local to_remove=$(echo "$key_value" | cut -d ':' -f 2)
                    key_value=$(relk_util_list_remove "$new_key_value" "$to_remove")
                fi
            elif [ -z "$new_key_value" ]; then
                key_value="$key_value"
            elif [ "$LIST_OPERATION" == "append" ]; then
                key_value=$(relk_util_list_append "$new_key_value" "$key_value")
            elif [ "$LIST_OPERATION" == "prepend" ]; then
                key_value=$(relk_util_list_prepend "$new_key_value" "$key_value")
            fi
        fi
    fi
    
    relk_platform_provider_call "$SOURCE_PROVIDER" 'set_key_value' "$SOURCE_PATH" "$NAMESPACE" "$key_name" "$key_value" "$value_type" "$attributes" "$key_constraints" "$force_write"

    hook_result=$(relk_platform_hook 'after_set_key' "$key_name" "$key_value" "$value_type" "$attributes" "$key_constraints") || exit
}

# <private>
# Gets a list of keys.
# imports: $NAMESPACE, $SOURCE
relk_get_keys() {
    relk_platform_provider_call "$SOURCE_PROVIDER" 'get_all_keys' "$SOURCE_PATH" "$NAMESPACE"
}

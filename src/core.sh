################################
# Relk Core Library
# Licensed under MIT License
################################

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
    if [[ "$value_type" == "t" || "$value_type" == "t:"* ]]; then
        local engine
        engine=$(echo "$value_type" | cut -d ':' -f 2)
        if [ "$engine" == "t" ]; then
            engine="default"
        fi
        key_value=$(relk_platform_template_call "$engine" "$key_value") || exit

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
# imports: $ENGINE
relk_in() {
    local engine="$ENGINE"
    if [ -z "$engine" ]; then
        engine="default"
    fi
    if [[ -p /dev/stdin ]]; then
        # read lines from stdin if available.
        while IFS= read -r line || [[ -n "$line" ]]; do
            relk_platform_template_call "$engine" "$line"
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
# Removes a key.
# imports: $NAMESPACE, $SOURCE, $KEY, $KEYS
relk_remove_key() {
    local remove_result
    remove_result=$(relk_platform_provider_call "$SOURCE_PROVIDER" 'remove_key_value' "$SOURCE_PATH" "$NAMESPACE" "$KEY" "$KEYS") || exit
}

# <private>
# Gets a list of keys.
# imports: $NAMESPACE, $SOURCE
relk_get_keys() {
    relk_platform_provider_call "$SOURCE_PROVIDER" 'get_all_keys' "$SOURCE_PATH" "$NAMESPACE"
}

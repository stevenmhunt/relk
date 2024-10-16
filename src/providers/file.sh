################################
# Relk File Provider: file
# Licensed under MIT License
################################

# Gets all keys in the keystore.
# parameters: 1: source path, 2: namespace
relk_platform_provider_file_get_all_keys() {
    local source_path="$1"
    local namespace="$2"

    local search_pattern="^$namespace${DELIM_COL}.*$"
    existing_entries=$(grep $search_pattern "$source_path" 2>/dev/null)
    if [[ -n "$existing_entries" ]]; then
        echo "$existing_entries" | cut -d "${DELIM_COL}" -f 2 | sort -u
    fi
}

# Gets the value of the requested key.
# parameters: 1: source path, 2: namespace, 3: key name, 4: key constraints
# output: value|attributes
relk_platform_provider_file_get_key_value() {
    local source_path="$1"
    local namespace="$2"
    local key_name="$3"
    local key_constraints="$4"
    local force_read="$5"

    # see if the key-value exists in CLI arguemtns.
    local -a key_pairs
    IFS="$DELIM_KEY" read -r -a key_pairs <<< "$key_constraints"
    for key_pair in "${key_pairs[@]}"; do
        local key="${key_pair%%=*}"
        local value="${key_pair#*=}"
        if [[ "$key" == "$key_name" ]]; then
            echo "$value|s"
            return
        fi
    done

    # get all potential matching key entries.
    local search_pattern="^$namespace${DELIM_COL}$key_name${DELIM_COL}.*$"
    local existing_entries=$(grep $search_pattern "$source_path" 2>/dev/null)

    # check if there are no potential matches.
    if [[ -z "$existing_entries" ]]; then
        if [[ "$force_read" == "1" ]]; then
            echo "|s"
            return
        else
            return 4
        fi
    fi

    # review the potential matches based on the requested constraints.
    local any_match_found=false
    local results=()
    while IFS="${DELIM_COL}" read -r file_namespace file_key file_value file_attributes file_constraints; do
        local -a file_constraints_array
        local -a request_constraints_array
        IFS="$DELIM_KEY" read -r -a file_constraints_array <<< "$file_constraints"
        IFS="$DELIM_KEY" read -r -a request_constraints_array <<< "$key_constraints"
        
        local match_found=true
        local constraint_count=0

        # Loop through each requested constraint
        for file_constraint in "${file_constraints_array[@]}"; do
            # Check if this requested constraint exists in the file's constraints
            if ! [[ "${request_constraints_array[*]}" =~ "$file_constraint" ]]; then
                # If the requested constraint is not found in the file's constraints
                match_found=false
                break
            fi
            ((constraint_count++))
        done

        if $match_found; then
            results+=("$file_value${DELIM_COL}$file_attributes${DELIM_COL}$constraint_count")
            any_match_found=true
        fi
    done <<< "$existing_entries"

    # check if no matches were found in potential matches.
    if ! $any_match_found; then
        if [[ "$force_read" == "1" ]]; then
            echo "|s"
            return
        else
            return 4
        fi
    fi

    # return the value with the highest number of matching constraints.
    local max_constraints=-1
    local final_result=""
    local final_result_attributes="s"
    for result in "${results[@]}"; do
        local value=$(echo "$result" | cut -d "${DELIM_COL}" -f 1)
        local value_attributes=$(echo "$result" | cut -d "${DELIM_COL}" -f 2)
        local constraint_count=$(echo "$result" | cut -d "${DELIM_COL}" -f 3)
        if (( constraint_count > max_constraints )); then
            max_constraints=$constraint_count
            final_result="$value"
            final_result_attributes="$value_attributes"
        fi
    done

    echo "$final_result|$final_result_attributes"
}

# Sets the value of the requested key.
# parameters: 1: source path, 2: namespace, 3: key name, 4: key value, 5: key value type, 6: key attributes, 7: key constraints, 8: force write
relk_platform_provider_file_set_key_value() {
    local source_path="$1"
    local namespace="$2"
    local key_name="$3"
    local key_value="$4"
    local key_value_type="$5"
    local key_attributes="$6"
    local key_constraints="$7"
    local force_write="$8"

    # check if an existing key-value pair with the requested constraints already exists.
    local search_pattern="^$namespace${DELIM_COL}$key_name${DELIM_COL}.*${DELIM_COL}$key_constraints$"
    local existing_entry=$(grep $search_pattern "$source_path" 2>/dev/null)
    local file_attributes="$key_value_type$([[ -n "$key_attributes" ]] && echo ",")$key_attributes"
    local new_record="$namespace${DELIM_COL}$key_name${DELIM_COL}$key_value${DELIM_COL}$file_attributes${DELIM_COL}$key_constraints"

    if [[ -n "$existing_entry" ]]; then
        if [[ "$force_write" == "1" ]]; then
            # Remove the existing entry and add the new one
            sed -i '' -e "/${search_pattern}/d" "$source_path" 2> /dev/null
            echo "$new_record" >> "$source_path"
        else
            return 3
        fi
    else
        # Store the new key-value combination with dependent keys and namespace
        echo "$new_record" >> "$source_path"
    fi
}

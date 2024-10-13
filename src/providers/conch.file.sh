#!/usr/bin/env bash
# Conch File Provider: file
# Licensed under MIT License

# Gets all keys in the keystore.
# parameters: 1: $SOURCE_PATH, 2: $NS
conch_file_get_all_keys() {
    SOURCE_PATH="$1"
    NS="$2"
    search_pattern="^$NS${DELIM_COL}.*$"
    existing_entries=$(grep $search_pattern "$SOURCE_PATH" 2>/dev/null)
    if [[ -n "$existing_entries" ]]; then
        echo "$existing_entries" | cut -d "${DELIM_COL}" -f 2 | sort -u
    fi
}

# Gets the value type of the requested key.
# parameters: 1: $SOURCE_PATH, 2: $NS, 3: $KEYNAME, 4: $KEY_CONSTRAINTS
conch_file_get_key_value_type() {
    SOURCE_PATH="$1"
    NS="$2"
    KEYNAME="$3"
    KEY_CONSTRAINTS="$4"
    search_pattern_all="^$NS${DELIM_COL}$KEYNAME${DELIM_COL}.*$"
    existing_entry_all=$(grep $search_pattern_all "$SOURCE_PATH" 2>/dev/null)
    
    if [[ -n "$existing_entry_all" ]]; then
        echo "$existing_entry_all" | head -n 1 | cut -d "${DELIM_COL}" -f 4
    fi
}

# Gets the value of the requested key.
# parameters: 1: $SOURCE_PATH, 2: $NS, 3: $KEYNAME, 4: $KEY_CONSTRAINTS
conch_file_get_key_value() {
    SOURCE_PATH="$1"
    NS="$2"
    KEYNAME="$3"
    KEY_CONSTRAINTS="$4"

    # see if the key value exists in the requested constraints.
    IFS="$DELIM_KEY" read -r -a key_value_pairs <<< "$KEY_CONSTRAINTS"

    for pair in "${key_value_pairs[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        if [[ "$key" == "$KEYNAME" ]]; then
            export KEY_TYPE="s"
            echo "$value|$KEY_TYPE"
            return
        fi
    done

    # get all matching key entries
    search_pattern="^$NS${DELIM_COL}$KEYNAME${DELIM_COL}.*$"
    existing_entries=$(grep $search_pattern "$SOURCE_PATH" 2>/dev/null)

    if [[ -z "$existing_entries" ]]; then
        return 4
    fi

    any_match_found=false
    results=()
    while IFS="${DELIM_COL}" read -r file_namespace file_key file_value file_type file_constraints; do
        IFS="$DELIM_KEY" read -r -a file_constraints_array <<< "$file_constraints"
        IFS="$DELIM_KEY" read -r -a request_constraints_array <<< "$KEY_CONSTRAINTS"
        
        match_found=true
        # Loop through each requested constraint
        constraint_count=0
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
            results+=("$file_value${DELIM_COL}$file_type${DELIM_COL}$constraint_count")
            any_match_found=true
        fi
    done <<< "$existing_entries"

    if ! $any_match_found; then
        return 4
    fi

    # return the value with the highest number of matching constraints
    max_constraints=-1
    final_result=""
    final_result_type="s"
    for result in "${results[@]}"; do
        value=$(echo "$result" | cut -d "${DELIM_COL}" -f 1)
        value_type=$(echo "$result" | cut -d "${DELIM_COL}" -f 2)
        constraint_count=$(echo "$result" | cut -d "${DELIM_COL}" -f 3)
        if (( constraint_count > max_constraints )); then
            max_constraints=$constraint_count
            final_result="$value"
            final_result_type="$value_type"
        fi
    done

    export KEY_TYPE="$final_result_type"
    echo "$final_result|$final_result_type"
}

# Sets the value of the requested key.
# parameters: 1: $SOURCE_PATH, 2: $NS, 3: $KEYNAME, 4: $KEY_VALUE, 5: $KEY_VALUETYPE, 6: $KEY_CONSTRAINTS, 7: $FORCE
conch_file_set_key_value() {
    SOURCE_PATH="$1"
    NS="$2"
    KEYNAME="$3"
    KEY_VALUE="$4"
    KEY_VALUETYPE="$5"
    KEY_CONSTRAINTS="$6"
    FORCE="$7"

    search_pattern="^$NS${DELIM_COL}$KEYNAME${DELIM_COL}.*${DELIM_COL}$KEY_CONSTRAINTS$"
    existing_entry=$(grep $search_pattern "$SOURCE_PATH" 2>/dev/null)
    new_record="$NS${DELIM_COL}$KEYNAME${DELIM_COL}$KEY_VALUE${DELIM_COL}$KEY_VALUETYPE${DELIM_COL}$KEY_CONSTRAINTS"

    if [[ -n "$existing_entry" ]]; then
        if [[ "$FORCE" == "1" ]]; then
            # Remove the existing entry and add the new one
            sed -i '' -e "/${search_pattern}/d" "$SOURCE_PATH"
            echo "$new_record" >> "$SOURCE_PATH"
        else
            return 3
        fi
    else
        # Store the new key-value combination with dependent keys and namespace
        echo "$new_record" >> "$SOURCE_PATH"
    fi
}
#!/bin/bash

# parameters: 1: $SOURCE_PATH,
# vars: $NAMESPACE
conk_file_get_all_keys() {
    SOURCE_PATH=$1
    search_pattern="^$NAMESPACE${DELIM_COL}.*$"
    existing_entries=$(grep $search_pattern "$SOURCE_PATH" 2>/dev/null)
    if [[ -n "$existing_entries" ]]; then
        echo "$existing_entries" | cut -d "${DELIM_COL}" -f 2 | sort -u
    fi
}

# parameters: 1: $SOURCE_PATH, 2: $KEYNAME
# vars: $KEY, $KEYS, $NAMESPACE
conk_file_get_key_value_type() {
    SOURCE_PATH=$1
    KEYNAME="${2:-$KEY}"
    search_pattern_all="^$NAMESPACE${DELIM_COL}$KEYNAME${DELIM_COL}.*$"
    existing_entry_all=$(grep $search_pattern_all "$SOURCE_PATH" 2>/dev/null)
    
    if [[ -n "$existing_entry_all" ]]; then
        echo "$existing_entry_all" | head -n 1 | cut -d "${DELIM_COL}" -f 4
    fi
}

# parameters: 1: $SOURCE_PATH, 2: $KEYNAME
# vars: $KEY, $KEYS, $NAMESPACE
conk_file_get_key_value() {
    SOURCE_PATH=$1
    KEYNAME="${2:-$KEY}"

    # see if the key value exists in the requested constraints.
    IFS="$DELIM_KEY" read -r -a key_value_pairs <<< "$KEYS"

    for pair in "${key_value_pairs[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        if [[ "$key" == "$KEYNAME" ]]; then
            echo "$value"
            return
        fi
    done

    # get all matching key entries
    search_pattern="^$NAMESPACE${DELIM_COL}$KEYNAME${DELIM_COL}.*$"
    existing_entries=$(grep $search_pattern "$SOURCE_PATH" 2>/dev/null)

    if [[ -z "$existing_entries" ]]; then
        conk_error "No matching value could be found for the key '$KEYNAME'."
        exit 4
    fi

    any_match_found=false
    results=()
    while IFS="${DELIM_COL}" read -r file_namespace file_key file_value file_type file_constraints; do
        IFS="$DELIM_KEY" read -r -a file_constraints_array <<< "$file_constraints"
        IFS="$DELIM_KEY" read -r -a request_constraints_array <<< "$KEYS"
        
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
            results+=("$file_value${DELIM_COL}$constraint_count")
            any_match_found=true
        fi
    done <<< "$existing_entries"

    if ! $any_match_found; then
        conk_error "No matching value could be found for the key '$KEYNAME' with the provided constraints."
        exit 4
    fi

    # return the value with the highest number of matching constraints
    max_constraints=-1
    final_result=""
    for result in "${results[@]}"; do
        value="${result%%${DELIM_COL}*}"
        constraint_count="${result#*${DELIM_COL}}"
        if (( constraint_count > max_constraints )); then
            max_constraints=$constraint_count
            final_result="$value"
        fi
    done

    echo "$final_result"
}

# parameters: $KEY, $VALUE, $VALUE_TYPE, $KEYS, $NAMESPACE, $IS_FORCED
conk_file_set_key() {
    SOURCE_PATH=$1

    search_pattern="^$NAMESPACE${DELIM_COL}$KEY${DELIM_COL}.*${DELIM_COL}$KEYS$"
    existing_entry=$(grep $search_pattern "$SOURCE_PATH" 2>/dev/null)
    new_record="$NAMESPACE${DELIM_COL}$KEY${DELIM_COL}$VALUE${DELIM_COL}$VALUE_TYPE${DELIM_COL}$KEYS"

    if [[ -n "$existing_entry" ]]; then
        if [[ "$IS_FORCED" == "true" ]]; then
            # Remove the existing entry and add the new one
            sed -i "/${search_pattern}/d" "$SOURCE_PATH"
            echo "$new_record" >> "$SOURCE_PATH"
        else
            conk_error "An entry for key '$KEY' with the same constraints already exists. Use the -f flag to overwrite this value."
            exit 3
        fi
    else
        # Store the new key-value combination with dependent keys and namespace
        echo "$new_record" >> "$SOURCE_PATH"
    fi
}
################################
# Relk Timestamp Extension
# Licensed under MIT License
################################

relk_platform_extension_timestamp_before_set_key() {
    local key_name=$(echo "$1" | cut -d '|' -f 1)
    local key_value=$(echo "$1" | cut -d '|' -f 2)
    local value_type=$(echo "$1" | cut -d '|' -f 3)
    local attributes=$(echo "$1" | cut -d '|' -f 4)
    local key_constraints=$(echo "$1" | cut -d '|' -f 5)

    local current_time="${RELK_CURRENT_TIME:-$(date +%s)}"
    relk_debug "[Timestamp] current time: $current_time"

    # set the creation time attribute.
    if [[ "$attributes" == "ts="* || "$attributes" =~ ",ts=" ]]; then
        attributes=$(echo "$attributes" | sed "s/\bts=[^,]*/ts=$current_time/")
    elif [[ -n "$attributes" ]]; then
        attributes+=",ts=$current_time"
    else
        attributes="ts=$current_time"
    fi

    echo "$key_name|$key_value|$value_type|$attributes|$key_constraints"
}

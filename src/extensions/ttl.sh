################################
# Relk TTL Extension
# Licensed under MIT License
################################

relk_platform_extension_ttl_get_extensions() {
    echo "timestamp"
}

relk_platform_extension_ttl_after_get_key() {
    local key_value="$1"
    local key_name="$2"
    local attributes="$4"
    local current_time="${RELK_CURRENT_TIME:-$(date +%s)}"

    # skip TTL processing if the value is already empty.
    if [[ -z "$key_value" ]]; then
        echo "$key_value"
        return
    fi

    # check if the value has attributes for both ttl and timestamp.
    if [[ (("$attributes" == "ttl="* || "$attributes" =~ ",ttl=") && ("$attributes" == "ts="* || "$attributes" =~ ",ts=")) ]]; then
        local ttl creation_time expiration_time

        ttl=$(echo "$attributes" | grep -oP "(?<=\bttl=)[^,]+")
        creation_time=$(echo "$attributes" | grep -oP "(?<=\bts=)[^,]+")
        expiration_time=$((creation_time + ttl))

        relk_debug "[TTL] after_get_key() key: $key_name, creation time: $creation_time, ttl: $ttl"

        if [[ "$current_time" -ge "$expiration_time" ]]; then
            relk_debug "[TTL] after_get_key() value for key $key_name is expired."
            key_value=""
        fi
    fi

    echo "$key_value"
}

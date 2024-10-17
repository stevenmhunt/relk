################################
# Relk TTL Extension
# Licensed under MIT License
################################

relk_platform_extension_ttl_after_get_key() {
    local result="$1"
    local attributes="$2"
    local key_name="$3"

    relk_debug "platform_extension_ttl_after_get_key() key_name: $key_name, result: $result, attributes: $attributes"

    if [[ "$attributes" =~ "ttl=" ]]; then
        echo ""
    else
        echo "$result"
    fi
}

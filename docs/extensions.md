# Relk Extension Specification

You can write a custom `relk` extensions by writing bash functions as shown below. Also remember to adhere to the [Relk Error Codes](./errors.md) to ensure error conditions are handled appropriately. Unlike providers, you only have to implement the below functions that your extension requires.

## Changing Data

All `relk` extension functions allow changes to the first argument passed in. The expectation from the platform call is that you will output either the original argument or a modified version of it. If an error occurs in your extension, then the original passed-in first argument will be used instead.

## Bash Functions

### `relk_platform_extension_<extension>_get_extensions`
This function is used when initializing a platform hook to load any additional dependencies. For example, the `ttl` extension depends on `time` because it requires a timestamp to work properly.
#### Expected Output
A newline-delimited list of other extensions that need to be loaded.

### `relk_platform_extension_<extension>_before_get_key`
This function is called before calling a provider to search for a matching key.
#### Parameters
- `$1`: `<key name>|<key constraints>`
- `$2`: `1` if the call is directly from the CLI, otherwise `0`.
#### Changeable Values
- `key name`: The name of the key being retrieved.
- `key constraints`: A comma-separated list of constraint key-value pairs.
#### Expected Output
Either the value `$1` or a modified version.

### `relk_platform_extension_<extension>_after_get_key`
This function is called after calling a provider to search for a matching key.
#### Parameters
- `$1`: key value
- `$2`: key name
- `$3`: key type
- `$4`: attributes
- `$5`: `1` if the call is directly from the CLI, otherwise `0`.
#### Changeable Values
- `key value`: The value of the key being retrieved.
#### Expected Output
Either the value `$1` or a modified version.

### `relk_platform_extension_<extension>_before_set_key`
This function is called before calling a provider to set a key-value pair.
#### Parameters
- `$1`: `<key name>|<key value>|<key type>|<attributes>|<key constraints>`
#### Changeable Values
- `key name`: The name of the key-value pair being created.
- `key value`: The value of the key-value pair being created.
- `key type`: The value of the key-value pair being created.
- `attributes`: A comma-separated list of attributes for the key-value pair being created.
- `key constraints`: A comma-separated list of constraint key-value pairs.
#### Expected Output
Either the value `$1` or a modified version.

### `relk_platform_extension_<extension>_after_set_key`
This function is called after calling a provider to set a key-value pair.
#### Parameters
- `$1`: key name
- `$2`: key value
- `$3`: key type
- `$4`: attributes
- `$5`: key constraints
#### Changeable Values
None.

## Example Implementation

This extension is called "demo". It sets all key values as "demo".

```bash
relk_platform_extension_demo_before_set_key() {
    local key_name=$(echo "$1" | cut -d '|' -f 1)
    local key_value=$(echo "$1" | cut -d '|' -f 2)
    local value_type=$(echo "$1" | cut -d '|' -f 3)
    local attributes=$(echo "$1" | cut -d '|' -f 4)
    local key_constraints=$(echo "$1" | cut -d '|' -f 5)

    # set the key value to "demo"
    key_value="demo"

    echo "$key_name|$key_value|$value_type|$attributes|$key_constraints"
}

export -f relk_platform_extension_demo_before_set_key

relk set-key test-key "some value"
relk get-key test-key
# some value

relk set-key test-key "something" -f -e demo
relk get-key test-key
# demo
```
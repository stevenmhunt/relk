# Relk Provider Specification

You can write a custom `relk` data source provider by writing bash functions as shown below. Also remember to adhere to the [Relk Error Codes](./errors.md) to ensure error conditions are handled appropriately.

## Required Bash Functions

### `relk_platform_provider_<provider>_get_all_keys`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
#### Expected Output
A newline-delimited, unique, a-z sorted list of keys.

### `relk_platform_provider_<provider>_get_key_value`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
- `$3`: Key name
- `$4`: Key constraints, comma separated: k1=k2,k2=v2,....,kN=vN
#### Expected Output
A pipe delimited value: `<key value>|<key value type>|<key attributes>`

### `relk_platform_provider_<provider>_set_key_value`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
- `$3`: Key name
- `$4`: Value
- `$5`: Key Attributes
- `$6`: Key constraints, comma separated: k1=k2,k2=v2,....,kN=vN
- `$7`: Force Write (1 or 0)
#### Expected Output
None

### `relk_platform_provider_<provider>_remove_key_value`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
- `$3`: Key name
- `$4`: Key constraints, comma separated: k1=k2,k2=v2,....,kN=vN
#### Expected Output
Outputs 1 if the record was removed, 0 if no matching record was found.

## Example Implementation

This provider is called "foo" and it only supports read operations. There is only one key called "foo" whose value is based on the specified source path. This example is provided to demonstrate how to configure the shell to support additional providers. If you are writing an executable, you will still need to create wrapper bash functions to allow for the integration.

```bash
relk_platform_provider_foo_get_all_keys() {
    # only one key available: foo
    echo "foo"
}

relk_platform_provider_foo_get_key_value() {
    # use the source path as the value.
    echo "$1|s|"
}

relk_platform_provider_foo_set_key_value() {
    # throw an IO error.
    return 5
}

relk_platform_provider_foo_remove_key_value() {
    # throw an IO error.
    return 5
}

export -f relk_platform_provider_foo_get_all_keys
export -f relk_platform_provider_foo_get_key_value
export -f relk_platform_provider_foo_set_key_value

relk get-keys -s "foo:bar"
# returns "foo"

relk get-key foo -s "foo:bar"
# returns "bar"

relk set-key foo something -s "foo:bar"
# returns "[ERROR]..."
```
# Conch Provider Specification

You can write a custom `conch` data source provider by writing bash functions as shown below. Also remember to adhere to the [Conch Error Codes](./errors.md) to ensure error conditions are handled appropriately.

## Required Bash Functions

### `conch_provider_<provider>_get_all_keys`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
#### Output
A newline-delimited, unique, a-z sorted list of keys.

### `conch_provider_<provider>_get_key_value`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
- `$3`: Key name
- `$4`: Key constraints, comma separated: k1=k2,k2=v2,....,kN=vN
#### Output
A pipe delimited value, where the first value is the value of the requested key and the second value is the value type.

### `conch_provider_<provider>_set_key_value`
#### Parameters
- `$1`: Source path (file path, db connection string, etc.)
- `$2`: Namespace
- `$3`: Key name
- `$4`: Value
- `$5`: Value Type
- `$6`: Key constraints, comma separated: k1=k2,k2=v2,....,kN=vN
- `$7`: Forced (1 or 0)
#### Output
None

## Example Implementation

This provider is called "foo" and it only supports read operations. There is only one key called "foo" whose value is based on the specified source path. This example is provided to demonstrate how to configure the shell to support additional providers. If you are writing an executable, you will still need to create wrapper bash functions to allow for the integration.

```bash
conch_provider_foo_get_all_keys() {
    # only one key available: foo
    echo "foo"
}

conch_provider_foo_get_key_value() {
    # use the source path as the value.
    echo "$1|s"
}

conch_provider_foo_set_key_value() {
    # throw an IO error.
    return 5
}

export -f conch_provider_foo_get_all_keys
export -f conch_provider_foo_get_key_value
export -f conch_provider_foo_set_key_value

conch get-keys -s "foo:bar"
# returns "foo"

conch get-key foo -s "foo:bar"
# returns "bar"

conch set-key foo something -s "foo:bar"
# returns "[ERROR]..."
```
# Conch 🐚 - Convergent Keystore

A lightweight, shell-based command-line tool designed to store, retrieve, and manage key/value pairs and their relationships with other key/values.

## Installation

**Requirements**: Bash 4

Copy the contents of this repository to the target machine, `cd` to the directory, and run the following command:

```bash
sudo ./install.sh
```

A `conch` shell script will be installed in `/usr/local/bin` with supporting files being installed in `./usr/local/share/conch`.

## Usage

### Creating Keys

To get started, create a simple key using `set` as follows:

```bash
conch set mykey "my value"
```

You can then retrieve the value using `get`:

```bash
conch get mykey
```

### Constraints

Moving beyond basic key/value pair storage, you can add key constraints when creating and retrieving key values:

```bash
conch set mykey "another value" -k anotherkey=something
```

This new value for `mykey` can co-exist with the original value added in the earlier example because the first key/value has no constraints, while this new value has the constraint of `anotherkey=something`. Let's go ahead and retrieve this new value:

```bash
conch get mykey -k anotherkey=something
```

### Templates

When creating key/value pairs, you can create a template value which can then be reused with different combinations of constraints and allows you to construct new values dynamically:

```bash
conch set mytemplate -t "this is my template value: {mykey}"
```

When you retrieve a template value, it will automatically interpolate keys based on either the constraints provided or pull values from key/value pairs which have already been stored:

```bash
conch get mytemplate
# returns "this is my template value: my value"

conch get mytemplate -k anotherkey=something
# returns "this is my template value: another value"

conch get mytemplate -k mykey="custom value"
# returns "this is my template value: custom value"
```

The `conch get` command will always attempt to locate a matching key/value pair with the highest number of matching constraints based on the request, with lower-numbered matches acting as layers of default values.

### Executing Commands

Templates can also be used to execute commands such as `base64` or `sed` to interactively process key/value pair data:

```bash
conch set base64 -t "{value:base64}"

conch get base64 -k value="some value"
# returns "c29tZVwgdmFsdWUK"
```

Additionally, you can add `sed` scripts directly and they will be detected and executed if the text of the command after the colon starts with `s/`:

```bash
conch set foobar -t "{value:s/foo/bar/g}"

conch get foobar -k value="food"
# returns "bard"
```

You can also reference external variables from the shell:

```bash
export TEST_VARIABLE=123

conch set testvar -t "{\$TEST_VARIABLE}"

conch get testvar
# returns "123"
```

### Namespaces

All commands in `conch` support the `-n <namespace>` flag which allows you to organize your key/value pairs into separate areas. The default namespace is "default".

### Sources

By default, all key/value pairs are written to a text file `~/.conchfile`. You can specify the data source for `conch` to use with the `-s "<provider>:<path>"` flag. The only currently implemented provider is `file`, but future implementations are possible.

### Managing Context

You can create and use contexts to automatically set flags in your specific environment. To set flags for a context, run the following command:

```bash
conch set-context -f my-namespace
```

Any future `conch` calls from the current directory or child directories will apply the specified flags to executed commands. The flags are written to `$PWD/.conch` and `conch` will scan all parent directories of `$PWD` when loading the context.

To retrieve the current context, use `conch get-context`. You can also append to an existing context with `conch add-context` and remove the existing context with `conch remove-context`.

### Additional Examples

If you have one or more values associated with different development environments such as `dev`, `test`, `staging`, `prod`, etc. you can use constraints and templates in `conch` to build out commonly needed URLs:

```bash
conch set api-protocol "https"
conch set api-tld "myproduct.com"
conch set api-subdomain "api-dev" -k env=dev
conch set api-subdomain "api-test" -k env=test
conch set api-subdomain "api-stg" -k env=staging
conch set api-subdomain "api" -k env=prod

conch set api-url -t "{api-protocol}://{api-subdomain}.{api-tld}/{app}"

conch get api-url -k env=dev -k app=mytestapp
# returns "https://api-dev.myproduct.com/mytestapp"
```

In the example above, you could override the values for `api-protocol` or `api-tld` for a specific environment by setting a new key/value pair with the appropriate constraints or setting them directly in the command using the `-k` flag.
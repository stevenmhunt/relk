# Conch 🐚 - Convergent Keystore

A lightweight, shell-based command-line tool designed to store, retrieve, and manage key/value pairs and their relationships with other key/values.

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/stevenmhunt/conch/main.yml)
![GitHub License](https://img.shields.io/github/license/stevenmhunt/conch)
![GitHub Release](https://img.shields.io/github/v/release/stevenmhunt/conch?include_prereleases)
[![bash](https://img.shields.io/badge/bash-&ge;4.0-lightgrey.svg?style=flat)](https://www.gnu.org/software/bash/)

## Installation

Copy the contents of this repository to the target machine, `cd` to the directory, and run the following command:

```bash
make install
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

If you need to force the reading a key without an error regardless of the result, or overwrite an existing key/value pair, use the `-f` flag:

```bash
conch get non-existent-key -f
# (no output)

conch set overwrite-key "initial value"
conch set overwrite-key "nvm" -f
conch get overwrite-key
# nvm
```

### Constraints

Moving beyond basic key/value pair storage, you can add key constraints when creating and retrieving key values:

```bash
conch set mykey "another value" -k anotherkey=something
```

This new value for `mykey` can co-exist with the original value added in the earlier example because the first key/value has no constraints, while this new value has the constraint of `anotherkey=something`. Let's go ahead and retrieve this new value:

```bash
conch get mykey -k anotherkey=something
# another value
```

### Templates

When creating key/value pairs, you can create a template value which can then be reused with different combinations of constraints and allows you to construct new values dynamically:

```bash
conch set mytemplate -t "this is my template value: {mykey}"
```

When you retrieve a template value, it will automatically interpolate keys based on either the constraints provided or pull values from key/value pairs which have already been stored:

```bash
conch get mytemplate
# this is my template value: my value

conch get mytemplate -k anotherkey=something
# this is my template value: another value

conch get mytemplate -k mykey="custom value"
# this is my template value: custom value
```

The `conch get` command will always attempt to locate a matching key/value pair with the highest number of matching constraints based on the request, with lower-numbered matches acting as fallback values.

#### Running Shell Commands

Templates can also be used to execute commands such as `base64` or `sed` to interactively process key/value pair data:

```bash
conch set base64 -t "{value:base64}"

conch get base64 -k value="some value"
# c29tZVwgdmFsdWUK
```

#### Running Sed Commands

Additionally, you can add `sed` scripts directly in the template and they will be detected and executed if the text of the command after the colon starts with `s/`:

```bash
conch set foobar -t "{value:s/foo/bar/g}"

conch get foobar -k value="food"
# bard
```

#### Conditions

You can add conditions to a variable reference which controls whether or not that variable's value is outputted:

```bash
conch set condition-key-1 -t "{value?:some-condition = 'yes'}"
conch set condition-key-2 -t "{value?:some-condition = 'yes' or another-key = 5}"

conch get condition-key-1 -k value=test -k some-condition=yes
# test

conch get condition-key-1 -k value=another-test -k some-condition=no
# (no output)

conch get condition-key-2 -k value=something -k another-key=5
# something
```

#### Referencing External Variables

You can also reference external variables from the shell:

```bash
export TEST_VARIABLE=123

conch set testvar -t "{\$TEST_VARIABLE}"

conch get testvar
# returns "123"
```

#### Pipes

You can pipe input from `stdin` using the `conch in` or `conch -` command. Consider the following YAML file `config.yaml`:

```yaml
name: {app}
env: {env}
http:
  url: {api-url}
```

You can construct different versions of the config file by piping the file through `conch`:

```bash
# construct a dev configuration for your application.
cat config.yaml | conch - -k env=dev > config.dev.yaml

# construct a test configuration for your application.
cat config.yaml | conch - -k env=test > config.test.yaml
```

### Lists

Another value type that can be used with `conch` are lists. You can use the `-l` flag to specify the value type as a list, and then provide a comma separated list of values:

```bash
conch set items -l "1,2,3"
```

When list values are outputted, each element in the list will appear in their own line:

```bash
conch get items
# 1
# 2
# 3
```

You can also use list values in conjunction with templates to produce multi-line outputs:

```bash
conch set item-names -t "Item #{items}"
conch get item-names
# Item #1
# Item #2
# Item #3
```

If a template contains multiple references to keys with list values, the number of lines of output will be the list lengths multiplied together. For example: given a template of `{list1}-{list2}` where `list1` has 5 items and `list2` has 4 items, executing the template will produce 20 lines of output.

As with other types of key/value pairs in `conch`, you can override list values with other list values or even string values by using key constraints when calling `conch get`:

```bash
conch get item-names -k items="1"
# Item #1
```

Also, when using templates which reference values, if a list contains zero elements then there will be no output:

```bash
conch set empty-list -l ""
conch set empty-template -t "you should not see this {empty-list}"
conch get empty-template
# (no output)
```

### Namespaces

All commands in `conch` support the `-n <namespace>` flag which allows you to organize your key/value pairs into separate areas. The default namespace is "default".

### Sources

By default, all key/value pairs are written to a text file `~/.conchfile`. You can specify the data source for `conch` to use with the `-s "<provider>:<path>"` flag. The only currently implemented provider is `file`, but future implementations are possible.

### Managing Context

You can create and use contexts to automatically set flags in your specific environment. To set flags for a context, run the following command:

```bash
conch set-context -n my-namespace
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
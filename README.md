# Relk - Relational Key Store

A lightweight, shell-based command-line tool designed to store, retrieve, and manage key-value pairs and their relationships.

[![MacOS](https://img.shields.io/github/actions/workflow/status/stevenmhunt/relk/macos-latest.yml?label=MacOS)](https://img.shields.io/github/actions/workflow/status/stevenmhunt/relk/macos-latest.yml)
[![Ubuntu](https://img.shields.io/github/actions/workflow/status/stevenmhunt/relk/ubuntu-latest.yml?label=Ubuntu)](https://img.shields.io/github/actions/workflow/status/stevenmhunt/relk/ubuntu-latest.yml)
[![Windows](https://img.shields.io/github/actions/workflow/status/stevenmhunt/relk/windows-git.yml?label=Windows)](https://img.shields.io/github/actions/workflow/status/stevenmhunt/relk/windows-git.yml)
![GitHub License](https://img.shields.io/github/license/stevenmhunt/relk)
![GitHub Release](https://img.shields.io/github/v/release/stevenmhunt/relk?include_prereleases)
[![bash](https://img.shields.io/badge/bash-&ge;4.0-lightgrey.svg?style=flat)](https://www.gnu.org/software/bash/)

## Installation

Copy the contents of this repository to the target machine, `cd` to the directory, and run the following command:

```bash
make install
```

A `relk` shell script will be installed in `/usr/local/bin` with supporting files being installed in `./usr/local/share/relk`.

## Usage

### Creating Keys

To get started, create a simple key using `set` as follows:

```bash
relk set mykey "my value"
```

You can then retrieve the value using `get`:

```bash
relk get mykey
```

If you need to force the reading a key without an error regardless of the result, or overwrite an existing key-value pair, use the `-f` flag:

```bash
relk get non-existent-key -f
# (no output)

relk set overwrite-key "initial value"
relk set overwrite-key "nvm" -f
relk get overwrite-key
# nvm
```

### Constraints

Moving beyond basic key-value pair storage, you can add key constraints when creating and retrieving key values:

```bash
relk set mykey "another value" -k anotherkey=something
```

This new value for `mykey` can co-exist with the original value added in the earlier example because the first key-value has no constraints, while this new value has the constraint of `anotherkey=something`. Let's go ahead and retrieve this new value:

```bash
relk get mykey -k anotherkey=something
# another value
```

### Templates

When creating key-value pairs, you can create a template value which can then be reused with different combinations of constraints and allows you to construct new values dynamically:

```bash
relk set mytemplate -t "this is my template value: {mykey}"
```

When you retrieve a template value, it will automatically interpolate keys based on either the constraints provided or pull values from key-value pairs which have already been stored:

```bash
relk get mytemplate
# this is my template value: my value

relk get mytemplate -k anotherkey=something
# this is my template value: another value

relk get mytemplate -k mykey="custom value"
# this is my template value: custom value
```

The `relk get` command will always attempt to locate a matching key-value pair with the highest number of matching constraints based on the request, with lower-numbered matches acting as fallback values.

#### Shell Commands

Templates can also be used to execute commands such as `base64` or `grep` to interactively process key-value pair data using the `:` or `:|` operator:

```bash
relk set base64 -t "{value:base64}"

relk get base64 -k value="some value"
# c29tZVwgdmFsdWUK

relk set grep -t "{value:|grep 'test'}"

relk get grep -k "test-value"
# test-value
```

#### Sed Commands

Additionally, you can add `sed` scripts directly in the template and they will be detected and executed using the `:#` operator:

```bash
relk set foobar -t "{value:#s/foo/bar/g}"

relk get foobar -k value="food"
# bard
```

#### Conditions

You can add conditions to a variable reference which controls whether or not that variable's value is outputted using the `:?` operator:

```bash
relk set condition-key-1 -t "{value:?some-condition = 'yes'}"
relk set condition-key-2 -t "{value:?some-condition = 'yes' or another-key = 5}"

relk get condition-key-1 -k value=test -k some-condition=yes
# test

relk get condition-key-1 -k value=another-test -k some-condition=no
# (no output)

relk get condition-key-2 -k value=something -k another-key=5
# something
```

#### Defaults

You can specify a default value if the value of the variable reference is empty using the `:=` operator:

```bash
relk set empty-value ""
relk set default-key -t "{empty-value:='default value'}"

relk get default-key
# default value
```

#### Command Chaining

You can use multiple types of commands in the same template key reference. For example, you can use a conditional expression and then a default value if the condition fails:

```bash
relk set condition-key-3 -t "{value:?some-condition = 'yes':='something else'}"

relk get condition-key-3 -k value=test -k some-condition=yes
# test

relk get condition-key-3 -k value=another-test -k some-condition=no
# something else
```

#### Referencing External Variables

You can also reference external variables from the shell:

```bash
export TEST_VARIABLE=123

relk set testvar -t "{\$TEST_VARIABLE}"

relk get testvar
# returns "123"
```

#### Pipes

You can pipe input from `stdin` using the `relk in` or `relk -` command. Consider the following YAML file `config.yaml`:

```yaml
name: {app}
env: {env}
http:
  url: {api-url}
```

You can construct different versions of the config file by piping the file through `relk`:

```bash
# construct a dev configuration for your application.
cat config.yaml | relk - -k env=dev > config.dev.yaml

# construct a test configuration for your application.
cat config.yaml | relk - -k env=test > config.test.yaml
```

### Lists

Another value type that can be used with `relk` are lists. You can use the `-l` flag to specify the value type as a list, and then provide a comma separated list of values:

```bash
relk set items -l "1,2,3"
```

When list values are outputted, each element in the list will appear in their own line:

```bash
relk get items
# 1
# 2
# 3
```

You can also use list values in conjunction with templates to produce multi-line outputs:

```bash
relk set item-names -t "Item #{items}"
relk get item-names
# Item #1
# Item #2
# Item #3
```

If a template contains multiple references to keys with list values, the number of lines of output will be the list lengths multiplied together. For example: given a template of `{list1}-{list2}` where `list1` has 5 items and `list2` has 4 items, executing the template will produce 20 lines of output.

As with other types of key-value pairs in `relk`, you can override list values with other list values or even string values by using key constraints when calling `relk get`:

```bash
relk get item-names -k items="1"
# Item #1
```

Also, when using templates which reference values, if a list contains zero elements then there will be no output:

```bash
relk set empty-list -l ""
relk set empty-template -t "you should not see this {empty-list}"
relk get empty-template
# (no output)
```

### Namespaces

All commands in `relk` support the `-n <namespace>` flag which allows you to organize your key-value pairs into separate areas. The default namespace is "default".

### Sources

By default, all key-value pairs are written to a text file `~/.relkfile`. You can specify the data source for `relk` to use with the `-s "<provider>:<path>"` flag. The only currently implemented provider is `file`, but future implementations are possible.

### Managing Context

You can create and use contexts to automatically set flags in your specific environment. To set flags for a context, run the following command:

```bash
relk set-context -n my-namespace
```

Any future `relk` calls from the current directory or child directories will apply the specified flags to executed commands. The flags are written to `$PWD/.relk` and `relk` will scan all parent directories of `$PWD` when loading the context.

To retrieve the current context, use `relk get-context`. You can also append to an existing context with `relk add-context` and remove the existing context with `relk remove-context`.

### Additional Examples

If you have one or more values associated with different development environments such as `dev`, `test`, `staging`, `prod`, etc. you can use constraints and templates in `relk` to build out commonly needed URLs:

```bash
relk set api-protocol "https"
relk set api-tld "myproduct.com"
relk set api-subdomain "api-dev" -k env=dev
relk set api-subdomain "api-test" -k env=test
relk set api-subdomain "api-stg" -k env=staging
relk set api-subdomain "api" -k env=prod

relk set api-url -t "{api-protocol}://{api-subdomain}.{api-tld}/{app}"

relk get api-url -k env=dev -k app=mytestapp
# returns "https://api-dev.myproduct.com/mytestapp"
```

In the example above, you could override the values for `api-protocol` or `api-tld` for a specific environment by setting a new key-value pair with the appropriate constraints or setting them directly in the command using the `-k` flag.
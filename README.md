# conk 🐚 - Convergent Keystore

A lightweight, shell-based command-line tool designed to store, retrieve, and manage key/value pairs and their relationships with other key/values.

## Installation

Copy the contents of this repository to the target machine, `cd` to the directory, and run the following command:

```bash
sudo ./install.sh
```

A `conk` shell script will be installed in `/usr/local/bin` with supporting files being installed in `./usr/local/share/conk`.

## Usage

### Creating Keys

To get started, create a simple key using `set` as follows:

```bash
conk set mykey "my value"
```

You can then retrieve the value using `get`:

```bash
conk get mykey
```

### Constraints

Where `conk` starts to get more powerful is the use of key constraints when creating and retrieving key values:

```bash
conk set mykey "another value" -k anotherkey=something
```

This new value for `mykey` can co-exist with the original value added in the earlier example because the first key/value has no constraints, while this new value has the constraint of `anotherkey=something`. Let's go ahead and retrieve this new value:

```bash
conk get mykey -k anotherkey=something
```

### Templates

When creating key/value pairs, you can create a template value which can then be reused with different combinations of constraints and allows you to create values:

```bash
conk set mytemplate -t "this is my template value: {mykey}"
```

When you retrieve a template value, it will automatically interpolate keys based on either the constraints provided or pull values from key/value pairs which have already been stored:

```bash
conk get mytemplate
# returns "this is my template value: my value"

conk get mytemplate -k anotherkey=something
# returns "this is my template value: another value"

conk get mytemplate -k mykey="custom value"
# returns "this is my template value: custom value"
```

The `conk get` command will always attempt to locate a matching key/value pair with the highest number of matching constraints based on the request, with lower-numbered matches acting as various levels of default values.

### Executing Commands

Templates can also be used to execute commands such as `base64` or `sed` to interactively process key/value pair data:

```bash
conk set base64 -t "{value:base64}"

conk get base64 -k value="some value"
# returns "c29tZVwgdmFsdWUK"
```

Additionally, you can add `sed` scripts directly and they will be detected and executed if the text of the command after the colon starts with `s/`:

```bash
conk set foobar -t "{value:s/foo/bar/g}"

conk get foobar -k value="food"
# returns "bard"
```

### Additional Examples

If you have one or more values associated with different development environments such as `dev`, `test`, `staging`, `prd`, etc. you can use constraints and templates in `conk` to build out commonly needed URLs:

```bash
conk set api-protocol "https"
conk set api-tld "myproduct.com"
conk set api-subdomain "api-dev" -k env=dev
conk set api-subdomain "api-test" -k env=test
conk set api-subdomain "api-stg" -k env=stg
conk set api-subdomain "api" -k env=prd

conk set api-url -t "{api-protocol}://{api-subdomain}.{api-tld}/{app}"

conk get api-url -k env=dev -k app=mytestapp
# returns "https://api-dev.myproduct.com/mytestapp"
```

In the example above, you could override the values for `api-protocol` or `api-tld` for a specific environment by setting a new key/value pair with the appropriate constraints.
# Relk Template Engine Specification

You can write a custom `relk` template engines by writing bash functions as shown below. Also remember to adhere to the [Relk Error Codes](./errors.md) to ensure error conditions are handled appropriately.

## Required Bash Functions

### `relk_platform_template_<engine>_render`
#### Parameters
- `$1`: The template value
#### Expected Output
The resultant output from rendering the template

Note: In order to resolve other key-value pairs, your template engine code will need to call `relk_get_key`. For more a more detailed example of how to implement a fully featured template engine, refer to the `default` template engine that ships with the tool.

## Example Implementation

This engine is called "demo" and it replaces all instances of % with "demo".

```bash
relk_platform_template_demo_render() {
    local value="$1"
    echo "$value" | sed 's/\%/demo/g'
}

export -f relk_platform_template_demo_render

relk set template-key -t:demo "this is my %"

relk get template-key
# this is my demo

echo "this is another %" | ./relk - --engine demo
# this is another demo
```
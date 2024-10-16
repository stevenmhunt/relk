# Relk Error Codes

## 0 - OK
No error.

## 1 - Unknown Command
The requested command `relk <command>` is not recognized.

## 2 - Unknown Source Provider
The requested source provider from the source `<provider>:<path>` is not recognized.

## 3 - Key with Constraints Already Exists
This occurs when trying to write a key-value pair, but it already exists with the specified constraints. This error can be skipped by using the `-f` flag.

## 4 - Key-Value Pair with Constraints Not Found
No matching value could be found for the requested key with the provided constraints.

## 5 - Source Provider IO Error
This is a general error to handle network or file system problems when attempting to read or write the keystore.
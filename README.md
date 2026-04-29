# IntegrationTests

Framework for integration tests for processes that work on files in a directory.

Calling `executeTests(in:)` with a directory as argument, files with name `test.json` are being searched for in the directory, each of those being interpreted as a test.

Such a `test.json` could be as follow:

```json
{
    "source": "source",
    "test": "test",
    "reference": "reference",
    "executable": "$EXECUTABLE",
    "arguments": ["$FILE1", "$FILE2"],
    "ignore": [".gitignore", ".DS_Store", "Thumbs.db", "*.log"]
}
```

The values of `"source"`, `"test"`, and `"reference"` are interpreted as relative paths (which could contain ".." or "/"), defining directories relative to the directory of the test (where `test.json` resides).

The value of `"executable"` and the entries of `"arguments"` can start with `$`, in which case the rests of it is interpreted as the name of the executable which should hold the actual value.

The `"ignore"` values define the file names (including directory names) to be ignored for the comparison. The simple wildcard `*` can be used there.

The test is then used as follows:

1. The directory defined by `"test"` is cleared and then filled with copies of the files in the directory defined by `"source"`.
2. The value of the environment variable which is named as the value of `"environmentVariableForExecutable"` is used as the of an executable that is called with the argument defined by tzhe values of `"arguments"`. The current directory for this call is the directory defined by `"test`.
3. The content of the directory defined by `"test"` is then compared to content of the directory defined by `"reference"`.

All `.gitignore` files are ignored by this process.

The result for all tests is a mapping of the relative paths of the directories which contain the `test.json` files to the list of the files that differ in step 3.

An simple example is the test `executingTests()` (cf. the section "Testing").

## Testing

For testing of this package:

1. Add the environment variable `PACKAGE_DIRECTORY` pointing the directory of this package.
2. Add the environment variable `EXECUTABLE` pointing to an executable that takes _n_ paths to files as arguments but does not change these files (e.g. `/usr/bin/more`).
3. Add the environment variable `FILE1` of value `a.txt`.
4. Add the environment variable `FILE2` of value `b.txt`

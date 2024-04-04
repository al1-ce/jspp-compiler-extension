# Extension to js++ compiler

# Archived since I do not intend to work on it anymore (at least for now). And js++ is basically dead and had no update since 2021

## !!!Intended to use with [jspp-vscode](https://github.com/al1-ce/jspp-vscode)!!!

## Installation:

Copy `jsppext` into your js++ compiler location (directory with `js++` executable)

## Building:

### Prerequisites:

[D language](https://dlang.org) compiler is required. 

Clone repository and run `dub build -b release`. Dub is going to compile jsppext into
`bin` folder.

## Usage: 

All options for compiler (v.0.10.0) are fully translated and used in same way as js++ options with exception of `-o`.

Updated option `-o, --output` now compiles all main files in directory specified in source 
into directory specified after this option. Another way `-o` flag can be used is by specifying input as file then you can output it into either directory or file and also you can execute it.

## Stdout:

Also jsppext changes compile output to be more readable for any linters. \
Old format: [  ERROR  ] `ErrorCode`: `ErrorMessage` at line `Line` char `Pos` at `FileName` \
New format: `FilePath`(`Line`,`Pos`): Error[`ErrorCode`]: `ErrorMessage`. 

Mainly it addresses `FileName` part in original output. jsppext tries to predict filepath from error based on constructed file list for compilation. \
Important part is: this way of deducting filepath have a flaw in which if several files with 
same name have error only one will be picked (by path alphabetically).

### VSCode:

#### Error linting

Insert this into your vscode build task.

```json
"problemMatcher": [{ "owner": "js++","source": "js++","pattern": [{"file": 1, "line": 2, "column": 3, "severity": 4, "code": 5, "message": 6, "regexp": "regexp": "(.*?)\\((\\d+)\\,(\\d+)\\)\\: (Error|Warning)\\[(.*?)\\]\\: (.*)" }] }]
```

Or if you have [jspp-vscode](https://github.com/al1-ce/jspp-vscode) set up then add just:
```json
"problemMatcher": ["$jsppext"]
```

#### Build task command

This repository includes [example build task](vscode-build-task-example.json) with custom problem matcher.

## !IMPORTANT!

- If `--output` option is omitted then it defaults to `.` path.
- `jsppext --output` scans only for files with extensions `jspp`, `js++` and `jpp`.
- If source specified as filepath you can set output filepath. I.e. `jsppext src/main.jpp -o js/out.js`, else it's going to only change filename (`jsppext src/main.jpp -o js/` -> `js/main.js`).
- You cannot specify several files to compile, except if you specify directory. For that, please, use original compiler.

## Custom syntax (enabled by default when using config)

jsppext adds custom syntax and pre/post-processes files to convert it into syntax that js++ compiler can process. This functionality can be disabled with `-u` or `-unprocessed` flag. \
Custom functionality includes:
- Alias injection. Allows for `alias name = symbol;` syntax. `symbol` can be anything, `name` must fit function/variable naming standard (can start with `$` and must use alphanumeric symbols plus `_`)
- String literal replacement. Originally js++ uses `"` and `'` for strings, `` ` `` for chars, `"""` for multiline strings. Precompiler will allow for common usage, `"` for strings, `'` for chars, `` ` `` for multiline strings.
- Global module name. Declare modules on top of file with D-style syntax `module name;` instead of C-style `module name { /* code */ }`. js++ allows for only one main module per file so that syntax is better anyway.
- Import renames. All imports now are lowercase and `System` renamed to `std`. I.e `import System.Encoding` now going to be `import std.encoding`.
<!-- - Different symbol imports.  -->
- `Struct` and `const` are aliases. `Struct` is now alias to `Class` and `const` is alias to `final`. Struct aliasing will make no difference and const is explicitly hated in js++ so precompiler just going to replace them.
- Auto-execution of main funciton. If one of non-module files contains main function with signature `void main()` then it's going to be executed with injection of `document.addEventListener("DOMContentLoaded", main);` at the end of file.

You can disable certain custom syntax in project config file.

## Compiler configuration

Project can be initialised with `jsppext --init`. That will create `jsppconf.yaml` that is going to be references by jsppext when calling `jsppext --build` or `jsppext --run`.

### Config settings

| Name | Type | Description |
| :--- | :--- | :--- |
| name | string | Name of project, used to uniquely idedntify it. Must contain only ASCII alpha-numeric characters, "-" or "_". |
| description | string | Description of project. |
| compilerVersion | string | If set then certain js++ compiler version will be enforced to be used. |
| extensionVersion | string | If set then certain jsppext version will be enforced to be used. |
| homepage | string | URL of project website. |
| authors | string[] | List of project authors. |
| copyright | string | Copyright declaration. |
| license | string | License(s) under which the project can be used. |
| dependencies | string[] | !!UNUSED!! |
| build | object[] | List of build configurations. |
| defaultBuild | string | Default build configuration name. |

### Build settings

| Name | Type | Description |
| :--- | :--- | :--- |
| name |  | Name to be specified for use with `jsppext --build`. I.e `jsppext --build imageLib`. |
| sourcePath | string | Path to directory containing main file or to main file itself (any folder "source" or "src" is automatically used as a source path if no sourcePaths setting is specified). |
| outputPath | string | Path to directory or file to which compiler will output into ("js" folder in root of project will be used if `outputPath` is not set). |
| workingDirectory | string | !!UNUSED!! |
| excludedSourceFiles | string[] | Files that must be excluded when compiling project. |
| excludedDirectories | string[] | Directories that must be excluded when compiling project. `____jspp_temp` is always excluded by default. |
| supressedWarnings | string[] | List of warnings to supress. Works only when `noLint` setting is off. Warning code must look like `JSPPW0000` |
| disabledSyntaxChanges | string[] | List of disabled syntax changes (Custom syntax) if `preprocess` is enabled. Accepts: `"main"` (main autoexec), `"alias"` (alias syntax), `"string"` (string replacement, `` ` `` to `"""`, `'` to `` ` ``), `"import"` (import name manipulation, `std.encoding.uri` to `System.Encoding.URI`, `externals.dom` to `Externals.DOM`), `"module"` (changes module syntax from `module Name { /* code */ }` to `module name;` at top of file), `"struct"` (aliases `struct` to `class`), `"const"` (aliases `const` to `final`) |
| noLint | bool | If set to `true` then original js++ compiler output will be shown. Corresponds to `-n, --nolint` flag. |
| verbose | bool | If set to `true` then jsppext will output info about each step (scanning, preparing, etc). Corresponds to `-v, --verbose` flag. |
| debug | bool | If set to `true` then js++ will output debug files. Corresponds to `-d, --debug` flag. |
| preprocess | bool | If set to `false` then jsppext will not be preprocessing files. Corresponds to `-u, --unprocessed` flag. |
| async | bool | Allows usage of async/await. Must be used with preprocess enabled. Disabled by default. |
| enableFloat | bool | If set to `true` then jsppext will not replace float keyword with double. Disabled by default. |

### Await usage (disabled by default)

Please be aware that `async/await` is very unstable feature because of complexity of js++ compiler. `async/await` must be used cautiously and can be used ONLY in those cases:

- async must be declared in function signature **before type**. `visibility async type name() {}`
- async must be declared as **function in file-scope**, not method of class.
- await must be declared before execution of **named** function, not delegate one. `await name()`

Note that preprocessor will make all functions with name of `async type name()` function. Same for await.

This means that your async functions must carry a unique name across modules. Otherwise they all will become async.

Also note that you cannot declare async functions inside of class due to how js++ compiles those classes.

### Configuration example

```yaml
name: Example Program
description: Minimal example.
homepage: https://github.com/al1-ce/jspp-compiler-extension
authors: al1-ce
copyright: (c) 2022 al1-ce
license: MIT license
compilerVersion: 0.10.0
extensionVersion: 1.0.5
build: 
    # Test build to see that everything translates correctly
    test:
        sourcePath: src
        outputPath: js
        excludedSourceFiles: 
            - src/obsolete1.jpp
            - src/obsolete2.jpp
        supressedWarnings: 
            - JSPPW0000
            - JSPPW0001
        verbose: on
    # Release build
    release:
        sourcePath: src
        outputPath: web/js
defaultBuild: test
```

## Usage Example
Your source tree is:
```
src/
 ├─ main1.jpp
 ├─ main2.jpp
 ├─ main3.jpp
 ├─ notmain.js
 ├─ mainmod/
 │  └─ main4.jpp
 ├─ modules/
 │  ├─ innermodule1.jpp
 │  ├─ innermodule2.jpp
 │  └─ list/
 │     ├─ listmodule1.jpp
 │     └─ listmodule2.jpp
 └─ outermodule.jpp
```

`jsppext src/ -o js/` going to compile it into:

```
js/
 ├─ main1.js
 ├─ main2.js
 ├─ main3.js
 └─ mainmod/
    └─ main4.js
```

## Why?

Original js++ compiler "doesn't like" when there's more then one main file which results in 
problematic situation when you have several "main" files for separate pages. Which leads to
making build script where you need to keep track of each module you include per file.

jsppext is basic solution for that. It goes through all files in source and records all 
imports and all module declarations and automatically constructs a command for js++ compiler.

For example if you have main file `main.jpp` which imports `System`, `Custom.Foo` and `Custom.Bar`, where `Custom.Bar` imports `Custom.Foo` and `Custom.Baz`, `Custom.Foo` and `Custom.Baz` doesn't import anything and you have unused `Custom.Faz`, `jspp src/ -o js/` is going to construct a command `js++ src/main.jpp src/custom/foo.jpp src/custom/bar.jpp src/custom/baz.jpp -o js/main.js`. This output command includes only main file, modules that this main file imports and modules that imported in modules (accounted for recursion). And so, even if you have many main files, jsppext is going to pick only things that is needed.

Plus now I'm able to extend syntax and make js++ feel more refined and unique as language.

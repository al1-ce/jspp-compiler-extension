import std.stdio: writef, writefln, readln, stdin, stdout;
import std.getopt: getopt, GetoptResult, config;
import std.array: popFront, popBack, join, split, replace;
import std.file: readText, exists, isFile, mkdirRecurse, dirEntries, SpanMode, thisExePath, write, getcwd, remove;
import std.path: buildNormalizedPath, absolutePath, isValidPath, dirSeparator, dirName, relativePath;
import std.process: execute, environment, executeShell, Config, spawnProcess, wait;
import std.conv: to;
import std.regex;
import std.algorithm.searching: startsWith, endsWith, canFind;

import std.stdio: writeln, write, File;

import sily.getopt;

bool _verbose = false;

int main(string[] args) {
    string _usage = "jsppext [options] [file]\n";

    bool _debug = false;
    bool _execute = false;
    string _targetPath = "";
    bool _version = false;
    bool _nolint = false;

    GetoptResult helpInfo = getopt(
        args, 
        config.passThrough,
        "debug|d", "Comile in debug mode", &_debug,
        "execute|e", "Execute input JS++ program", &_execute,
        "output|o", "Output target", &_targetPath,
        "version", "Display the JS++ compiler version and exit", &_version,
        "auto|a", "Autocompile file into specified directory", &_targetPath,
        "verbose|v", "Produces verbose output", &_verbose,
        "nolint|n", "Removes error transcription (outputs js++ out instead of jsppext).", &_nolint
    );

    string jsppPath = thisExePath().dirName() ~ dirSeparator ~ "js++";
    version (Windows) jsppPath ~= ".exe";

    if (_version) {
        wait(spawnProcess([jsppPath, "--version"]));
        return 0;
    }

    string[] nargs = args.dup;

    if (nargs.length == 1) {
        writefln("Error: Please specify filepath.");
        return 1;
    }

    if (helpInfo.helpWanted) {
        Commands[] com = [];
        printGetopt("", _usage, com, helpInfo.options);
        return 0;
    }
        
    string _srcPath = nargs[1].buildNormalizedPath;
    string _oldPath = nargs[1].buildNormalizedPath.absolutePath;

    if (_targetPath == "") _targetPath = ".";

    if (!_targetPath.isValidPath()) {
        writefln("Error: Path \"%s\" is not valid.", _targetPath);
        return 1;
    }

    if (!_srcPath.exists()) {
        writefln("Error: Path \"%s\" is not valid.", _srcPath);
        return 1;
    }

    if (!_srcPath.isFile && _targetPath.isPathFile()) {
        writefln("Error: Cannot output directory into file. Please specify directory for --output, not file.");
        return 1;
    }

    if (nargs.length > 2) {
        writeln("Warning: Cannot set more then one file or directory to compile, other files are omitted.");
    }

    FileEntry[] mainFiles;
    FileEntry[] modules;

    string absScanPath = _oldPath;
    string scanPath = _srcPath;

    if (_srcPath.isFile) {
        absScanPath = _oldPath.dirName();
        scanPath = _srcPath.dirName();
    } 

    auto entries = dirEntries(absScanPath, "*.{jspp,jpp,js++}", SpanMode.depth);

    writelnVerbose("Compiling programs & module lists\n");
    
    foreach (file; entries) {
        int cp = processFile(file.name, mainFiles, modules, absScanPath, scanPath);
        if (cp != 0) return cp;
    }

    writelnVerbose("\nCompiling programs import lists\n");

    foreach (FileEntry f; mainFiles) {
        if (_srcPath.isFile && f.name != _oldPath) continue;
        writelnVerbose(f.name.replace(absScanPath, scanPath).buildNormalizedPath);
        string[] imports = [];
        int cp = compileImports(f, modules, imports);
        if (cp != 0) return cp;

        if (imports.length > 0) {
            writelnVerbose("    Imports: ");
        } else {
            writelnVerbose("    No imports");
        }

        string[] _args = [f.name.replace(absScanPath, scanPath).buildNormalizedPath];

        for (int i = 0; i < imports.length; i++) {
            string imprt = imports[i];
            _args ~= imprt.replace(absScanPath, scanPath).buildNormalizedPath;
            writelnVerbose("    " ~ imprt.replace(absScanPath, scanPath).buildNormalizedPath);
        }

        bool _doOutput = true;

        if (_debug) _args ~= "-d";
        if (_execute) {
            if (_srcPath.isFile) {
                _args ~= "-e";
                _doOutput = false;
            } else {
                writeln("Warning: Directory auto doesn't work with execute.");
            }
        }

        if (_doOutput) {
            _args ~= "-o";
            
            if (!_targetPath.buildNormalizedPath.isPathFile()) {
                auto re = regex(r"(?<=\.)(?:jpp|jspp|js\+\+)$");

                _args ~= f.name.replace(absScanPath, _targetPath).buildNormalizedPath.replaceAll(re, "js");

                string outPath = f.name.replace(absScanPath, _targetPath).buildNormalizedPath.dirName();

                if (!outPath.exists) {
                    mkdirRecurse(outPath);
                }
            } else {
                auto re = regex(r"(?<=\.)(?:jpp|jspp|js\+\+)$");
                string newPath = _targetPath.buildNormalizedPath.replaceAll(re, "js");
                _args ~= newPath;

                string outDir = newPath.dirName();

                if (!outDir.exists) {
                    mkdirRecurse(outDir);
                }

            }
        }

        writelnVerbose();
        writelnVerbose("Command for \"" ~ f.name.replace(absScanPath, scanPath).buildNormalizedPath ~ "\":");
        writelnVerbose((["js++"] ~ _args).join(" "));
        writelnVerbose();

        if (!_verbose && !_srcPath.isFile) 
            writefln("\n===== %s =====\n", f.name.replace(absScanPath, scanPath).buildNormalizedPath);

        if (_nolint) {
            wait(spawnProcess([jsppPath] ~ _args, stdin, stdout));
        } else {
            string coutPath = (_srcPath.isFile ? _oldPath.dirName : _oldPath) ~ dirSeparator ~ "____jspp_compilelog";
            auto processOut = File(coutPath, "w+");

            wait(spawnProcess([jsppPath] ~ _args, stdin, processOut));
            processOut.close();

            auto errRegex = 
                regex(r"(?:\[  ERROR  \] )(.*?)(?:\: )(.*?)(?: at line )(\d+?)(?: char )(\d+?)(?: at )(.*)");
            auto continueRegex = regex(r"( *?)(?: at )(.*)");
            auto parseRegex = regex(r"Parse Error: Line (\d*?)\: (.*) \((.*)\)");
            auto cout = File(coutPath, "r");
            string line;

            CompileError err;

            while ((line = cout.readln()) !is null) {
                auto cap1 = line.matchFirst(errRegex);
                auto cap2 = line.matchFirst(continueRegex);
                auto cap3 = line.matchFirst(parseRegex);
                if (!cap1.empty()) {
                    err = CompileError(cap1[1], ("0" ~ cap1[3]).to!int, ("0" ~ cap1[4]).to!int + 2, cap1[2], cap1[5]);

                    string errfile = findFilePath(err.file, mainFiles, modules);

                    err.file = errfile.buildNormalizedPath.relativePath(getcwd());

                    writefln( "%s(%d,%d): Error[%s]: %s.", err.file, err.line, err.pos, err.code, err.message );
                    // source\app.d(190,34): Error: undefined identifier `caap`, did you mean variable `cap`?
                } else 
                if (!cap2.empty()) {
                    err = CompileError(
                        err.code, 
                        ("0" ~ cap2[3]).to!int, 
                        ("0" ~ cap2[4]).to!int + 2, 
                        err.message, 
                        cap1[5]
                        );

                    string errfile = findFilePath(err.file, mainFiles, modules);

                    err.file = errfile.buildNormalizedPath.relativePath(getcwd());

                    writefln( "%s(%d,%d): Error[%s]: %s.", err.file, err.line, err.pos, err.code, err.message );
                } else 
                if (!cap3.empty()) {
                    err = CompileError("JSPPE0000", ("0" ~ cap3[1]).to!int, 0, cap3[2], cap3[3]);

                    string errfile = findFilePath(err.file, mainFiles, modules);

                    err.file = errfile.buildNormalizedPath.relativePath(getcwd());

                    writefln( "%s(%d,%d): Error[%s]: %s.", err.file, err.line, err.pos, err.code, err.message );
                } else {
                    write(line);
                }
            }
            cout.close();
            coutPath.remove();
        }
    }

    return 0;
}

struct CompileError {
    string code;
    int line;
    int pos;
    string message;
    string file;
}

struct FileEntry {
    string name;
    bool isModule;
    string[] imports;
    string moduleName;

    this(string _name) {
        name = _name;
        isModule = false;
        imports = [];
        moduleName = "";
    }
}

void writeVerbose(T...)(T args) {
    if (_verbose) write(args);
}

void writelnVerbose(T...)(T args) {
    if (_verbose) writeln(args);
}

bool isPathFile(string path) {
    auto re = regex(r"^.*?\.(?:\w+)$");
    auto cap = path.matchFirst(re);
    return !cap.empty();
}

string findFilePath(string file, FileEntry[] files) {
    for (int i = 0; i < files.length; i ++) {
        FileEntry e = files[i];
        if (e.name.endsWith(file)) {
            return e.name;
        }
    }
    return file;
}

string findFilePath(string file, FileEntry[] files1, FileEntry[] files2) {
    string _out = findFilePath(file, files1);
    if (_out == file) {
        return findFilePath(file, files2);
    }
    return _out;
}

int findModuleIndex(FileEntry[] entries, string moduleName) {
    int i = 0;
    foreach (FileEntry e; entries) {
        if (e.moduleName == moduleName) {
            return i;
        }
        i++;
    }

    return -1;
}

int processFile(string filename, ref FileEntry[] mainFiles, ref FileEntry[] modules, string opath, string srcpath) {
    FileEntry f = FileEntry(filename);
    string contents = readText(filename);
    auto modRegex = regex(r"^[^\S\r\n]*?module[^\S\r\n]+((?:\w+\.?)+)", "gm");
    auto impRegex = regex(r"^[^\S\r\n]*?import[^\S\r\n]+((?:\w+\.?)+)", "gm");

    auto mods = matchAll(contents, modRegex);
    foreach (mod; mods) {
        if (f.isModule == true) {
            writefln("Error: Found multiple module declarations in file \"%s\".", f.name);
            return 1;
        }
        f.isModule = true;
        f.moduleName = mod[1];
    }
    
    writelnVerbose(f.name.replace(opath, srcpath).buildNormalizedPath);
    if (f.isModule) {
        writelnVerbose("    Module " ~ f.moduleName);
    } else {
        writelnVerbose("    Main Program ");
    }

    auto impt = matchAll(contents, impRegex);
    foreach (imp; impt) {
        if (imp[1].startsWith("System", "Externals")) continue;
        f.imports ~= imp[1];
        writelnVerbose("    Import " ~ imp[1]);
    }
    // writeln(f.imports);

    if (f.isModule) {
        modules ~= f;
    } else {
        mainFiles ~= f;
    }
    writelnVerbose();

    return 0;
}

int compileImports(FileEntry file, FileEntry[] modules, ref string[] imports) {
    // writef("     : "); writeln(imports);
    // writef(file.name ~ " : "); writeln(file.imports);
    for (int i = 0; i < file.imports.length; i++) {
        string imp = file.imports[i];
        int idx = modules.findModuleIndex(imp);
        if (idx == -1) {
            writefln("Error: Can't find module \"%s\".", imp);
            return 1;
        }
        if (imports.canFindString(modules[idx].name)) continue;
        imports ~= modules[idx].name;
        int cp = compileImports(modules[idx], modules, imports);
        if (cp != 0) return cp;
    }
    return 0;
}

bool canFindString(string[] arr, string val) {
    for (int i = 0; i < arr.length; i ++) {
        if (arr[i] == val) return true;
    }
    return false;
}
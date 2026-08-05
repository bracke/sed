# Architecture

## Responsibilities

| Package | Owns |
| --- | --- |
| `Sed` | Process identity and the wide line-counter type. Pure, depends on nothing. |
| `Sed.Status` | The monotonic outcome accumulator and the exit-status mapping. |
| `Sed.Diagnostics` | Structured diagnostics as data: code, location, typed parameters. |
| `Sed.Diagnostics.Registry` | The one descriptor per code: severity, recoverability, status effect, owner, message key, parameter schema. |
| `Sed.Diagnostics.Quoting` | Escaping of untrusted values against terminal injection. |
| `Sed.Diagnostics.Rendering` | Turning a diagnostic into localized, optionally styled text. |
| `Sed.Command_Line` | The invocation model. Opens nothing, renders nothing, terminates nothing. |
| `Sed.Command_Line.Arguments` | The injected argument-list abstraction. |
| `Sed.Command_Line.Options` | The option registry and token parsing. |
| `Sed.Command_Line.Validation` | Semantic validation: whether the first operand is the script. |
| `Sed.Configuration` | The resolved, immutable settings for one run. |
| `Sed.Environment` | The process environment captured as a value. |
| `Sed.Localization` | The only package that names the message catalogue library. |
| `Sed.Terminal` | Styling policy, and the only package that names `terminal_styles`. |
| `Sed.Help` | Help and version output, generated from the option registry. |
| `Sed.Scripts` | Ordered script sources and the offset-to-source map. |
| `Sed.Scripts.Loading` | Reading `-f` files. |
| `Sed.Scripts.Compilation` | The compilation adapter over `sedlib`. |
| `Sed.Engine` | Translation of engine diagnostics into sed diagnostics. |
| `Sed.IO` | Byte-exact I/O abstractions: streams, filesystem, handles. |
| `Sed.IO.Filesystem` | The real filesystem, over `Ada.Streams.Stream_IO`. |
| `Sed.IO.Process_Streams` | The real standard streams and terminal detection. |
| `Sed.Input.Logical_Stream` | Every operand as one stream, with lookahead for `$`. |
| `Sed.Output.Standard` | Standard output for program data only. |
| `Sed.Output.Named_Files` | The `w` destination registry. |
| `Sed.Execution` | Running a compiled program. |
| `Sed.Execution.Environment` | The adapters that present input, output and resources to the engine. |
| `Sed.Application` | The only layer that coordinates all the others. |

## Dependency direction

```
sed_main
  -> Sed.Application
       -> Command_Line, Configuration, Scripts, Input, Output, Execution,
          Diagnostics.Rendering, Help
            -> Sed.Engine, Sed.Scripts.Compilation,
               Sed.Execution.Environment  -> sedlib
            -> Sed.Localization           -> messages
            -> Sed.Terminal               -> terminal_styles
            -> Sed.IO.*                   -> Ada.Streams, Ada.Text_IO
```

Rules the layout enforces:

* Only four packages name `sedlib`: `Sed.Engine`, `Sed.Scripts.Compilation`
  (and its `Engine` child), and `Sed.Execution.Environment`.
* `Sed.Command_Line` depends on `Sed.Diagnostics` and nothing else in the
  project. It never reaches the engine, the filesystem, the catalogue or the
  terminal.
* `Sed.Input` and `Sed.Output` depend on `Sed.IO` and `Sed.Diagnostics`. They
  know nothing about sed commands, message catalogues or styling, which is why
  the engine adapters, not the streams themselves, implement the engine's
  interfaces.
* `Sed.Diagnostics.Rendering` may use the catalogue and styling, but reads
  recoverability and status effect from the registry rather than deciding
  them.
* Only `Sed.Application` sets a process exit status.

## Execution lifecycle

`Sed.Application.Execute` runs a fixed order:

1. Parse tokens, and resolve the styling policy from whatever the command line
   managed to say about colour — so even the first malformed option is
   reported the way the user asked for.
2. Load the message catalogue.
3. Validate the invocation. A failure stops here with a diagnostic and a hint.
4. Handle `--help` or `--version` and stop, before any script is loaded.
5. Load every script source in exact command-line order. An unreadable `-f`
   file stops here, before any input operand is opened.
6. Compile through `sedlib`.
7. Only now create the `w` destinations, each exactly once.
8. Initialize the logical input stream over the operands.
9. Execute.
10. Flush standard output, close named outputs, close the input stream, and
    fold every cleanup failure into the status.

## Resource ownership

The invocation owns its command-line values; the source set owns script text
and the map back to it; the compiled program owns the engine program; the
logical stream owns the operand it currently has open; the named-output
registry owns its handles; the filesystem object owns every file handle it
issued. Closing is always explicit so that a deferred write error can be
reported. Finalization exists as a safety net, not as the normal path.

## Exception containment

Expected failures are structured results everywhere: a missing option
argument, a missing script, an unreadable file, a malformed script, an invalid
expression and a failed write are all values, not exceptions. Platform and Ada
I/O exceptions are caught at the subsystem boundary that raised them and
converted. `Sed.Application.Execute` has the single outermost handler: it
renders one localized internal-error diagnostic, sets internal-failure status,
and does not continue. No traceback is printed unless `SED_DEBUG` is set.

## Testing seams

Everything the program touches outside itself is injected:
`Argument_List`, `Input_Source_Interface`, `Output_Stream_Interface`,
`Filesystem_Interface` and `Process_Environment`. Tests supply in-memory
implementations and call `Sed.Application.Execute` — the same entry point the
process main uses. There is no test-only execution path.

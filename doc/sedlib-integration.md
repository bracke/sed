# sedlib integration

## Division of responsibility

`sedlib` owns the sed language entirely: script parsing, address parsing and
range state, regular-expression integration, substitution, every command's
execution, pattern and hold spaces, automatic printing, branching and labels,
cycle semantics, substitution-success state and command output events.

This program owns everything around that: the command line, script provenance,
the logical input stream, standard and named output, `r` and `w` filesystem
access, diagnostics, localization, styling and process status.

The program never parses a sed command or a regular expression itself, and it
never invokes an external `sed`.

## The contract used

| Capability | API |
| --- | --- |
| Compile a script | `Sedlib.Compilation.Compile (Script, Options)` |
| Structured compile diagnostics with byte offsets | `Sedlib.Compilation.Diagnostics`, `Sedlib.Diagnostics.Source_Span` |
| POSIX language gating | `Sedlib.Options.Portable_Mode` |
| POSIX basic regular expressions | `Sedlib.Options.Basic_Dialect` |
| Byte-exact text | `Sedlib.Options.Byte_Mode`, `Treat_Invalid_As_Bytes` |
| Finite bounds | `Sedlib.Options.Compile_Limits`, `Execution_Limits` |
| Automatic-print control | `Sedlib.Options.Set_Automatic_Output` |
| Compiled write destinations | `Sedlib.Programs.Kind`, `Text_Operand`, `Substitution_Write_Name` |
| Injected input | `Sedlib.Input.Record_Source` |
| Injected output | `Sedlib.Output.Event_Sink` |
| Injected resources | `Sedlib.Resources.Resource_Provider` |
| Execution | `Sedlib.Execution.Execute` |
| Structured runtime diagnostics | `Sedlib.Execution.Execution_Result` |

Compatibility is a compile-time matter: `alire.toml` pins `sedlib` exactly, so
an incompatible resolution cannot happen silently, and `sed_tools verify`
checks that the version the program reports matches the pin.

## Multiple script sources

`Sedlib.Compilation.Compile` takes one script string. POSIX defines the script
as the concatenation of every `-e` and `-f` value separated by newlines, so
concatenation is the specified behaviour rather than a workaround — but the
provenance of each byte must survive it.

`Sed.Scripts` performs the join and records, for every unit, its start offset,
byte span, start line and line span in the result. `Locate` maps any offset
back to the originating unit and to a line and column *inside that unit*.
Since engine diagnostics carry a 0-based byte offset, every compile failure is
reported against the `-e` expression or the `-f` file the user actually wrote.

A newline always separates units, so `-e 's/a/b/' -e 'p'` cannot become
`s/a/b/p`, while `-e 'a\' -e 'text'` still forms the single multiline text
command POSIX defines.

A future `sedlib` that accepted an ordered list of named source units would let
this mapping move into the library. Until then the mapping is here, and it is
tested directly (SCRIPT-MAP-001).

## Input, output and resources

The logical input stream, the standard-output writer and the `w` registry know
nothing about the engine. `Sed.Execution.Environment` supplies three adapters
that implement the engine's interfaces on top of them. That is what keeps the
I/O layer free of engine types and lets every layer be tested on its own.

`$` needs one record of lookahead. The engine does that itself over the
injected source, so a single stream spanning all operands gives correct `$`
across files without this program telling the engine anything about files.

For `r`, the provider returns the whole file, or empty text when the file does
not exist or cannot be opened — POSIX's "treat as an empty file, causing no
error condition". For `w`, the provider writes through the registry, which has
already created every destination the compiled program named.

## Limits

The engine enforces finite bounds by design, which suits a library embedded in
a server. A command-line stream editor must process whatever the host can
hold, so this program raises them to values no realistic script reaches: one
gibibyte for byte-valued bounds and the widest count the engine accepts for
event and instruction bounds. The mechanism stays in place — exceeding a bound
is still a structured `Resource_Exhausted` diagnostic, never a crash or a
silent truncation.

## Corrections made to sedlib

Building this program surfaced four defects and one missing capability. Each
was fixed in `sedlib`, with tests added there:

* The POSIX multiline `a\`, `i\` and `c\` forms were not implemented; only the
  one-line extension was accepted.
* A regular-expression address was never attached to a command group, so
  `/re/{...}` ran on every line and `/re/!{...}` on none.
* The substitution output buffer was stack-allocated at the full pattern-space
  limit, so raising that limit turned substitution into a stack overflow.
* The hold space started unterminated, so `x`, `g` and `G` on an untouched
  hold space produced no line and `sed G` did not double-space a file.
* `Sedlib.Options.Regexp_Dialect` was added, giving callers POSIX basic
  regular expressions. The default is unchanged, so no existing caller moves.

## Required future library changes

* An ordered multi-source compile API, so source provenance can be the
  library's rather than reconstructed from offsets here.

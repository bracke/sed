# sed

A POSIX-oriented command-line stream editor written in Ada 2022.

The executable owns invocation parsing, script provenance, the logical input
stream, standard and named output, localized diagnostics and process status.
It contains no sed language of its own: [`sedlib`](../sedlib) is the sole sed
parser and execution engine, and `regexp` is the sole regular-expression
engine. If a required behaviour is missing there, it is fixed there.

## Status

Prerelease, `0.1.0-dev`. The POSIX command set, address forms, substitution
and basic regular expressions are implemented and tested, and no conformance
gaps are open -- see [doc/posix-conformance.md](doc/posix-conformance.md) for
the feature-by-feature classification. The version stays a prerelease because
this is the first snapshot of a new program, not because anything is known to
be missing.

## Invocation

```
sed [-n] script [file...]
sed [-n] -e script [-e script]... [-f script_file]... [file...]
sed [-n] -f script_file [-e script]... [-f script_file]... [file...]
```

Options: `-n`, `-e`, `-f`, and the administrative `--help`, `--version`,
`--color=auto|always|never` and `--`. GNU extensions such as `-i`, `-E`, `-r`,
`-s`, `-u` and `-z` are not implemented and are rejected as unknown options
rather than silently accepted. See [doc/command-line.md](doc/command-line.md).

## Examples

```sh
sed 's/alpha/one/' input.txt        # substitute on every line
sed -n '/beta/p' input.txt          # print only matching lines
sed -e 's/a/A/' -e 's/b/B/' f       # several expressions, in order
sed -f rules.sed input.txt          # a script from a file
sed -n '$p' first.txt second.txt    # $ is the last line of both files
sed -- '-script'                    # a script that starts with a hyphen
```

All input operands form one logical stream: line numbers continue across
files, `$` matches only the final line of the whole stream, and execution
state never resets at a file boundary.

## Build requirements

* Alire 2.1 or later
* GNAT 15.2.1 (`gnat_native`)
* The `sedlib`, `regexp`, `terminal_styles`, `messages` and `i18n` crates,
  resolved through the local pins in `alire.toml`

Every build runs through Alire; there is no direct `gprbuild` workflow.

## Building, testing and verifying

```sh
alr build                                   # build the executable
cd tests && alr build                       # build the tests and tooling
cd tests && ./bin/sed_tools build           # build both crates
cd tests && ./bin/sed_tools test            # build, then run the AUnit suite
cd tests && ./bin/sed_tools verify          # test, then audit the repository
cd tests && ./bin/sed_tools docs            # check administrative output
cd tests && ./bin/sed_tools clean           # remove generated artifacts
cd tests && ./bin/sed_tools release         # the full release gate
```

All tooling is Ada, built on `project_tools`. There is no shell script,
makefile or other non-Ada build machinery in the repository, and
`sed_tools verify` fails if one appears.

## Localization and styling

Every user-facing string comes from the message catalogue at
`share/sed/messages/catalog.txt`, which ships as
`<prefix>/share/sed/messages/catalog.txt` and is resolved relative to the
executable. English and Danish are both maintained; `sed_tools verify` fails
if either locale is missing a key that a diagnostic or an option needs.

`--color` styles diagnostics only. Program data is never localized and never
styled, on any stream, under any colour mode.

## Known limitations

No conformance gaps are open. Bounds that exist -- pattern-space size, and the
recursion depth of a backreferenced match -- are set far beyond realistic use
and report a structured diagnostic rather than failing abruptly; see
[doc/security.md](doc/security.md).

## Documentation

| Document | Contents |
| --- | --- |
| [doc/architecture.md](doc/architecture.md) | Package responsibilities, dependency direction, lifecycle |
| [doc/command-line.md](doc/command-line.md) | Options, operands, streams, exit status |
| [doc/sedlib-integration.md](doc/sedlib-integration.md) | The engine contract and what it requires |
| [doc/posix-conformance.md](doc/posix-conformance.md) | Feature-by-feature classification and gaps |
| [doc/input-output-model.md](doc/input-output-model.md) | Bytes, newlines, the logical stream |
| [doc/diagnostics-and-localization.md](doc/diagnostics-and-localization.md) | Diagnostic model, catalogue, escaping |
| [doc/testing.md](doc/testing.md) | Suite organization and test identifiers |
| [doc/tooling.md](doc/tooling.md) | What each `sed_tools` command does |
| [doc/release.md](doc/release.md) | Versioning and the release gate |
| [doc/security.md](doc/security.md) | What a sed script can do, and what it cannot |
| [doc/ai-implementation-guide.md](doc/ai-implementation-guide.md) | Normative rules for changing this project |

## License

MIT. See [LICENSE](LICENSE).

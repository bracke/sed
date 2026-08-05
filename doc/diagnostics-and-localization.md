# Diagnostics and localization

## The model

A diagnostic is data, not text. It carries a stable code, an optional source
location, an optional related location, and a typed parameter set. Severity,
recoverability, process-status effect and owning subsystem are not stored on
the diagnostic: they are read from `Sed.Diagnostics.Registry`, which holds
exactly one descriptor per code. No subsystem can invent a competing policy
for a code it reports, and a test can assert a diagnostic structurally without
rendering it in any locale.

Parameters are typed. Text parameters (`path`, `option`, `value`, `detail`,
`capability`, `requirement`, `limit`) carry untrusted values; integer
parameters (`actual`, `allowed`) are formatted by the catalogue. Each code
declares which parameters it requires and which it accepts, and
`Schema_Satisfied` checks both directions — a missing requirement and an
unaccepted extra both fail.

## Codes

Invocation: unknown option, missing option argument, invalid option argument,
missing script. Script: open failure, read failure, syntax error, invalid
regular expression, undefined label, duplicate label. Input: open failure,
read failure. Output: standard-output failure, named-output open failure,
named-output write failure, `r` file read warning. Runtime: execution failure,
resource exhaustion, missing engine capability. Internal: unexpected failure.

The `r` file code is a warning with no status effect. POSIX says an `rfile`
that does not exist or cannot be opened is treated as an empty file with no
error condition, and that is implemented silently; the warning covers only a
host read fault after a successful open, where output is incomplete but POSIX
defines no error for it.

## Rendering

Rendered form is compiler-style:

```
sed: rules.sed:12:8: error: invalid regular expression
sed: input.txt: error: cannot read input file
sed: error: option '-e' requires an argument
```

The frame, the severity label and the location format are all catalogue
templates, so a translation controls word order and punctuation. Source
locations use plain decimal numbers rather than locale-grouped ones, because
they are machine-read as often as they are looked at.

## Escaping

Everything untrusted is escaped before it becomes a message argument: paths,
option spellings, labels, expression fragments and script excerpts. C0
controls, DEL and the escape character become backslash escapes, a backslash
is doubled, and bytes that do not form well-formed UTF-8 become `\xHH`.
Well-formed multi-byte UTF-8 passes through so non-ASCII paths stay readable.
A crafted path cannot emit escape sequences, move the cursor or recolour later
output.

Escaping is presentation only. The raw value is always what reaches the
filesystem.

Diagnostics never contain Ada package names, exception names, memory
addresses or tracebacks. The engine's stable code identifier does appear as
technical detail — it names a condition, not an implementation. `SED_DEBUG`
enables a development mode that adds exception information to the
internal-error diagnostic; it changes nothing else and is off by default.

## Localization

Every user-facing string comes from `share/sed/messages/catalog.txt`: usage,
help, option descriptions, version labels, diagnostics and hints. No English
is hard-coded in production code, no sentence is assembled from translated
fragments, and every argument is passed by name.

The catalogue is resolved from `SED_MESSAGE_CATALOG`, then from
`<executable directory>/../share/sed/messages/catalog.txt`. That second path
is the same whether the program runs from an installation prefix or from the
build tree, because `bin/` and `share/` are siblings in both. If no catalogue
can be loaded, every message renders as its own key: a visible installation
fault rather than a silent fallback to hard-coded text.

English and Danish are both maintained. `sed_tools verify` fails if either
locale is missing a key that a diagnostic code or a registered option needs,
so help can never describe an option the parser does not accept.

Sed data, script text, option spellings, labels, file names and source
excerpts are never translated. Line numbers produced by `=` are program data
and are locale-neutral.

# Changelog

All notable changes to this project are recorded here.

## 0.1.0-dev

First development snapshot of the sed command-line stream editor.

### Added

- POSIX invocation forms `sed [-n] script [file...]`, `-e` and `-f`, with
  attached and clustered short options, `--`, and `-` for standard input.
- Administrative `--help`, `--version` and `--color=auto|always|never`, which
  short-circuit before any script is loaded or any file is opened.
- Ordered script sources with full provenance: every `-e`, `-f` and positional
  occurrence is its own unit, joined by newlines as POSIX defines, and every
  diagnostic maps back to the unit, line and column the user wrote.
- One logical input stream over every operand, with continuous line numbering,
  correct `$` across files, lazy opening, and byte-exact handling of a final
  line without a newline.
- POSIX command set through `sedlib`: `p P = l d D q h H g G x n N a i c : b t
  y r w s` with grouping, negation and comments.
- POSIX basic regular expressions, selected through the new
  `Sedlib.Options.Regexp_Dialect` setting.
- Structured diagnostics with a stable code registry, typed parameters,
  severity, recoverability and process-status effect; all text from the
  `messages` catalogue in English and Danish; all untrusted values escaped
  against terminal injection.
- Stable exit statuses 0, 1, 2 and 3, accumulated monotonically.
- AUnit suite of 58 cases with stable identifiers, driving the real
  application through injected in-memory streams and filesystem.
- Ada tooling `sed_tools build | test | verify | docs | clean | release` built
  on `project_tools`.

### Fixed in dependencies

- `sedlib` now implements the POSIX multiline `a\`, `i\` and `c\` forms.
- `sedlib` now attaches a regular-expression address to a command group, so
  `/re/{...}` no longer runs on every line.
- `sedlib` no longer stack-allocates the substitution output buffer at the
  full pattern-space limit.
- `sedlib` now starts the hold space as an empty terminated line, so `x`, `g`
  and `G` on an untouched hold space produce an empty line. This is what makes
  `sed G` double-space a file.
- `regexp` now matches backreferences of more than one character. Expressions
  containing a backreference are walked by a backtracking matcher that gives
  each candidate path its own position and capture set; every other pattern
  keeps the linear-time simulation.

### Known limitations

None. `doc/posix-conformance.md` records no open conformance gaps.

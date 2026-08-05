# POSIX conformance

This document classifies every feature `sed` implements. The target is
POSIX `sed`, not GNU `sed`.

Classifications:

* **Conforming** — behaves as POSIX specifies.
* **Conforming (implementation-defined)** — POSIX permits a choice; the choice
  this program makes is stated.
* **Partially conforming** — the common case is right, a stated case is not.
  Every one of these has a gap identifier and a reproducing test.
* **Unsupported** — deliberately not implemented.
* **Extension** — beyond POSIX, and marked as such.

Test identifiers name cases in `tests/src`. `sed_tools verify` fails if a gap
listed here has no test that reproduces it.

## Status of this release

This is a **prerelease** (`0.1.0-dev`). No conformance gaps are open: every
feature in the tables below is implemented and tested. The version stays a
prerelease because this is the first snapshot of a new program rather than
because anything is known to be missing, and `sed_tools release` enforces
that.

## Invocation and options

| Feature | Status | Evidence |
| --- | --- | --- |
| `sed [-n] script [file...]` | Conforming | CLI-VALID-001, CLI-VALID-002 |
| `sed [-n] -e script ... [file...]` | Conforming | CLI-VALID-003 |
| `sed [-n] -f script_file ... [file...]` | Conforming | SCRIPT-ORDER-001 |
| `-n` | Conforming | CMD-PRINT-001, OUTPUT-001 |
| `-e`, including attached and clustered forms | Conforming | CLI-VALID-004, CLI-VALID-005 |
| `-f` | Conforming | SCRIPT-ORDER-001, SCRIPT-DIAG-002 |
| Repeated `-n` | Conforming | CLI-VALID-006 |
| `--` ends option processing | Conforming | CLI-VALID-007 |
| `-` names standard input | Conforming | CLI-VALID-008, INPUT-002 |
| `--help`, `--version` | Extension | CLI-VALID-010, CLI-STATUS-002 |
| `--color=auto\|always\|never` | Extension | CLI-VALID-009, STYLE-001 |
| Unknown option is a failure | Conforming | CLI-ERROR-004, CLI-ERROR-005 |
| `-i -E -r -z -s -u --posix --regexp-extended` | Unsupported | CLI-ERROR-008 |

GNU options are rejected as unknown options rather than accepted as aliases,
so a script written for GNU `sed` fails loudly instead of behaving differently.

## Script sources

| Feature | Status | Evidence |
| --- | --- | --- |
| Sources apply in exact command-line order | Conforming | SCRIPT-ORDER-001 |
| Sources are separated by a newline, never merged | Conforming | SCRIPT-BOUNDARY-001 |
| A text command may span a source boundary | Conforming | SCRIPT-BOUNDARY-002 |
| Empty `-e` and empty `-f` are valid | Conforming | SCRIPT-BOUNDARY-003 |
| Diagnostics name the originating source, line and column | Conforming (implementation-defined) | SCRIPT-MAP-001, SCRIPT-DIAG-001, SCRIPT-DIAG-002 |
| An unreadable `-f` file is fatal before input is opened | Conforming | SCRIPT-LOAD-001 |

## Commands

| Command | Status | Evidence |
| --- | --- | --- |
| `p` `P` `=` `l` | Conforming | CMD-PRINT-001 |
| `d` `D` `q` | Conforming | CMD-DELETE-001, CMD-PRINT-001 |
| `h` `H` `g` `G` | Conforming | CMD-HOLD-001 |
| `x` | Conforming | CMD-HOLD-001 |
| `n` `N` | Conforming | CMD-CYCLE-001 |
| `a\` `i\` `c\` | Conforming | CMD-TEXT-001, SCRIPT-BOUNDARY-002 |
| `a text` on one line | Extension | covered by sedlib |
| `:` `b` `t` | Conforming | CMD-BRANCH-001 |
| `y` | Conforming | CMD-TRANSLIT-001 |
| `r` | Conforming | FILE-001 |
| `w`, `s///w` | Conforming | FILE-002, SCRIPT-WRITE-002 |
| `{` `}` and `!` | Conforming | CMD-GROUP-001 |
| `#` | Conforming | CMD-GROUP-001 |

A missing or unreadable `r` file is treated as an empty file and causes no
error condition, exactly as POSIX requires (FILE-001).

## Addresses

| Feature | Status | Evidence |
| --- | --- | --- |
| `number` | Conforming | ADDR-001 |
| `$` over the whole logical stream | Conforming | ADDR-001, INPUT-001 |
| `/BRE/` | Conforming | ADDR-001 |
| Two-address ranges, all combinations | Conforming | ADDR-001 |
| Range reactivation later in the stream | Conforming | ADDR-002 |
| Negation `!`, on commands and on groups | Conforming | ADDR-001, CMD-GROUP-001 |
| Zero-address and step address forms | Unsupported (GNU extensions) | rejected by the portable language mode |

## Regular expressions

Expressions are POSIX **basic** regular expressions. The `regexp` engine
implements an extended dialect, so `sedlib` translates BREs into it; that
translation is selected by `sed` through `Sedlib.Options.Basic_Dialect`.

| Feature | Status | Evidence |
| --- | --- | --- |
| `\( \)` group, `( )` ordinary | Conforming | SUB-002 |
| `\{ \}` bound, `{ }` ordinary | Conforming | SUB-002 |
| `+ ? \|` ordinary | Conforming | SUB-002 |
| `*` quantifies, literal in leading position | Conforming | SUB-002 |
| `^` and `$` anchor only where POSIX allows | Conforming | SUB-002 |
| `.`, bracket expressions, character classes | Conforming | SUB-001, SUB-002 |
| `[]a]`, `[^...]` | Conforming | SUB-002 |
| `\n` matches an embedded newline | Conforming | SUB-002, CMD-CYCLE-001 |
| Backreferences in a **replacement** (`\1`) | Conforming | SUB-001 |
| Backreferences in a **pattern** (`\1`) | Conforming | SUB-003 |

A backslash before an ordinary character is undefined in POSIX; this program
takes the character literally, which never invents a metacharacter.

## Substitution

| Feature | Status | Evidence |
| --- | --- | --- |
| First match, `g`, numeric occurrence, `Ng` | Conforming | SUB-001 |
| `p` flag, `w` flag | Conforming | SUB-001, FILE-002 |
| `&` and `\&` | Conforming | SUB-001 |
| Arbitrary and escaped delimiters | Conforming | SUB-001 |
| Empty replacement, no-match | Conforming | SUB-001 |
| Substitution success drives `t` | Conforming | CMD-BRANCH-001 |

## Input, output and status

| Feature | Status | Evidence |
| --- | --- | --- |
| All operands form one logical stream | Conforming | INPUT-001 |
| Line numbers continue across operands | Conforming | INPUT-001 |
| Empty operands contribute no line | Conforming | INPUT-001 |
| Standard input among named operands | Conforming | INPUT-002 |
| Repeated `-` does not rewind | Conforming | INPUT-002 |
| Final line without a newline is preserved | Conforming | INPUT-003 |
| Only the last output line may lack a newline | Conforming (implementation-defined) | INPUT-003 |
| Standard output carries only program data | Conforming | CLI-STATUS-001, STYLE-002 |
| Unreadable operand is reported, later operands still run | Conforming (implementation-defined) | FAIL-INPUT-001 |
| Exit status 0/1/2/3 | Conforming (implementation-defined) | STATUS-001 |

POSIX requires only "0 on success, >0 on error". The finer split into 1, 2 and
3 is implementation-defined and documented in `doc/command-line.md`.

## Open gaps

No conformance gaps are open.

Recording a new one means describing it here with observable behaviour,
responsible component, reproducing test and planned resolution; adding its
identifier to the gap list in `sed_tools`; and writing a test that asserts the
divergence, so that fixing the cause fails the test and forces the entry to be
closed. `sed_tools verify` checks that this section and that list agree.

## Closed gaps

### GAP-BACKREF-001 — a backreference in a pattern matched one character (fixed)

In a pattern, `\1` matched only the first character of a group that had
captured more than one. `s/\(a\)\1/X/` on `aa` was right; `s/\(ab\)\1/X/` on
`abab` was not.

The cause was in `regexp`: its matcher advances every live NFA thread in
lock-step by one input unit per step, and a backreference cannot be
represented that way, because how much text it consumes is not known until a
particular path is taken. A backreference is not a regular construct at all —
"the text is some string written twice" is not a regular language — so no
finite-automaton simulation can decide it.

`regexp` now walks backreferenced expressions with a backtracking matcher that
gives each candidate path its own position and its own capture set, and keeps
the linear-time simulation for every other pattern. Recursion depth is bounded
and converts to `Match_Limit_Exceeded`, so a pathological pattern over a very
long span is a determinate limit diagnostic rather than a stack overflow.

Covered by `Backreferences` in `regexp`, and by SUB-003 here.

### GAP-HOLD-001 — an untouched hold space printed without a newline (fixed)

`sed x` on `a\n` produced no output where other implementations produce a
single empty line, and `sed G` left a file unchanged instead of double-spacing
it.

The cause was narrower than first recorded: the terminator travelling with
each space is the correct model, and other implementations do the same. The
defect was only that `sedlib` started the hold space *unterminated*, making
that starting value observable through `x`, `g` and `G`. It now starts as an
empty terminated line. Fixed in `Sedlib.Execution`, with a dedicated test
there and CMD-HOLD-001 here.

## Corrections made in dependencies

Five defects were found and fixed while building this program. Each was fixed
in the crate that owned it, with tests added there:

* `sedlib` did not implement the POSIX multiline `a\`, `i\` and `c\` forms,
  accepting only the one-line extension. Implemented in
  `Sedlib.Compilation.Parse_Text_Command`, with seven tests.
* `sedlib` never attached a regular-expression address to a command group, so
  `/re/{...}` ran on every line and `/re/!{...}` on none. Fixed in the `{`
  branch of the compiler.
* `sedlib` allocated the substitution output buffer on the stack at the full
  pattern-space limit, so raising that limit turned substitution into a stack
  overflow. It now sizes the buffer from the data and holds it on the heap.
* `sedlib` started the hold space unterminated, so `x`, `g` and `G` on an
  untouched hold space produced no line. It now starts as an empty terminated
  line, which is what makes `sed G` double-space a file.
* `regexp` could not match a backreference of more than one character,
  because its lock-step matcher cannot represent a construct whose width
  depends on the path taken. It now backtracks for backreferenced
  expressions and keeps the linear path for everything else.

`sedlib` also gained `Sedlib.Options.Regexp_Dialect`, the opt-in POSIX basic
regular-expression mode this program selects. Its default is unchanged, so no
existing caller is affected.

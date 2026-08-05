# Testing

## Organization

The suite lives in the `sed_tests` child crate and runs through AUnit.

| Case | Covers |
| --- | --- |
| `Sed_Test_Suite.Command_Line` | Option parsing, validation, structural parse results, invocation status |
| `Sed_Test_Suite.Scripts` | Source ordering, boundaries, the source map, compile diagnostics, `w` destination discovery |
| `Sed_Test_Suite.Conformance` | Every POSIX command, address form, substitution, transliteration, the logical input stream, `r` and `w` |
| `Sed_Test_Suite.Robustness` | Status monotonicity, the diagnostic registry, escaping, styling, localization, failure injection, documented gaps |

## How tests run the program

Every case calls `Sed.Application.Execute` — the same entry point the process
main uses — with in-memory implementations of the argument list, the three
standard streams, the filesystem and the process environment. There is no
test-only execution path, so nothing can pass in tests and differ in
production.

Because the doubles are ordinary data structures, failure injection is exact
and repeatable on any host: `Fail_Open`, `Fail_Read`, `Fail_Create`,
`Fail_Write`, `Fail_Writes_After` and `Fail_Flush` say precisely what fails
and when. No test depends on filesystem permissions, a full disk, an
unwritable directory or a real terminal.

The doubles also observe what production code did: `Create_Count` proves a `w`
destination was truncated exactly once, and `Open_Count` proves no handle was
leaked.

## Test identifiers

Every routine carries a stable identifier that appears in its registered name,
so a failure names the requirement it broke and
`doc/posix-conformance.md` can cite the case that pins each claim.

Prefixes: `CLI-VALID`, `CLI-ERROR`, `CLI-STATUS`, `SCRIPT-ORDER`,
`SCRIPT-BOUNDARY`, `SCRIPT-MAP`, `SCRIPT-DIAG`, `SCRIPT-LOAD`, `SCRIPT-WRITE`,
`CMD-*`, `ADDR-*`, `SUB-*`, `INPUT-*`, `FILE-*`, `OUTPUT-*`, `STATUS-*`,
`DIAG-*`, `STYLE-*`, `LOCALE-*`, `FAIL-*`, and `GAP-*` for documented
limitations.

A `GAP-` test asserts the divergence rather than the correct behaviour. When
the underlying engine is fixed the test fails, which forces the gap to be
closed in the conformance document rather than quietly outliving the defect.

## Requirements

No mandatory test needs network access, an external `sed`, elevated
privileges, a real terminal or write access outside the test workspace. The
runner reports plainly and exits non-zero if any case fails.

## Running

```sh
cd tests && ./bin/sed_tools test
```

or, for the suite alone:

```sh
cd tests && alr build && ./bin/sed_tests_main
```

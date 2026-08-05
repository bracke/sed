# Implementation guide

Normative rules for changing this project. MUST, MUST NOT, SHOULD and MAY are
used in their usual sense.

## Identity

Root crate `sed`, binary, Ada 2022, root package namespace `Sed`, executable
`sed`, built from `src/main/sed_main.adb`. Child test crate `sed_tests` in
`tests/`. Licence MIT. Maximum line length 120.

## Dependencies

The root crate MUST depend only on `sedlib`, `terminal_styles` and `messages`.
The production closure MUST NOT contain AUnit, `project_tools` or any test
helper. The tests crate MAY depend on all of them.

## Layering

* Only `Sed.Engine`, `Sed.Scripts.Compilation` (and its `Engine` child) and
  `Sed.Execution.Environment` MAY name `sedlib`.
* Only `Sed.Localization` MAY name `messages`.
* Only `Sed.Terminal` MAY name `terminal_styles`.
* `Sed.Command_Line` MUST NOT depend on the engine, the filesystem, the
  catalogue or the terminal. It MUST NOT open files, render text or terminate.
* `Sed.Input` and `Sed.Output` MUST NOT depend on the engine, the catalogue or
  the terminal.
* `Sed.Diagnostics.Rendering` MUST NOT decide recoverability or process
  status; it reads them from the registry.
* Only `Sed.Application` MAY set a process exit status.

## Invariants

1. The CLI MUST NOT parse or execute any sed construct itself.
2. Script source order MUST be exact, and every unit MUST keep its provenance.
3. Input operands MUST form one logical stream; global line numbers MUST NOT
   decrease or reset.
4. Exactly one delivered record MAY be marked final.
5. Standard output MUST contain only program data during execution.
6. Program data MUST NOT be localized or styled.
7. Every production diagnostic MUST come from the catalogue.
8. Compilation MUST complete before any `w` destination is created.
9. Each `w` destination MUST be created at most once.
10. Status MUST accumulate monotonically.
11. Expected failures MUST be structured results, not exceptions.
12. Every supported feature MUST have a test; every limitation MUST have a gap
    identifier and a reproducing test.
13. All tooling MUST be Ada and MUST use `project_tools`.
14. All builds MUST run through Alire.
15. The program MUST NOT invoke an external `sed` or a shell.

## Adding a diagnostic

Add the code to `Sed.Diagnostics.Diagnostic_Code`; the registry aggregate then
fails to compile until it is described. Add its message key to both locales in
`share/sed/messages/catalog.txt`. Add a test. `sed_tools verify` checks the
catalogue side.

## Adding an option

Add it to `Sed.Command_Line.Options.Option_Id` and describe it in the table;
the aggregate enforces that. Add its help key to both locales. Help output is
generated from the registry, so it follows automatically. Add valid and
invalid parsing tests.

## When the engine is missing something

If a required POSIX behaviour is absent or wrong in `sedlib` or `regexp`, fix
it there, add tests there, then use it here. Do not reimplement it in this
crate. If it cannot reasonably be fixed, record a gap in
`doc/posix-conformance.md` with observable behaviour, responsible component,
reproducing test and planned resolution, and add a `GAP-` test that asserts
the divergence.

## Prohibited

Implementing sed commands or regular expressions in this crate; invoking an
external sed or a shell; reading all input into memory; using end-of-file
exceptions as control flow; styling program data; hard-coding English;
package-level mutable state; merging script sources without provenance;
setting exit status below the application layer; adding a persistent user
configuration file; adding telemetry or network access.

## Definition of done

`cd tests && ./bin/sed_tools verify` passes, the documentation matches the
implementation, and every claim in `doc/posix-conformance.md` cites a test
that exists.

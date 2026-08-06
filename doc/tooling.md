# Tooling

All project tooling is Ada, built on `project_tools`, and lives in the
`sed_tests` crate as the `sed_tools` executable. There is no shell script,
makefile, Python, Perl, Ruby or Node tooling in the repository; `sed_tools
verify` fails if one appears.

Every build runs through Alire. There is no direct `gprbuild` workflow.

```sh
cd tests && ./bin/sed_tools <command>
```

| Command | Does |
| --- | --- |
| `build` | Builds the root crate and the tests crate through Alire. |
| `test` | Builds, runs the AUnit suite, then checks administrative output. |
| `verify` | Runs `test`, then audits the repository. |
| `docs` | Runs the built executable's `--version` and `--help`. |
| `prove` | Runs GNATprove over the declared proof scope; skips if the prover is absent. |
| `clean` | Removes project-owned generated artifacts only. |
| `release` | Runs `verify`, then applies the release gate. |

With no argument, `sed_tools` runs `verify`.

## What verify audits

* **Forbidden tooling files** — no `*.sh`, `*.py`, `*.pl`, `*.rb`, `*.js`,
  `Makefile` or `CMakeLists.txt` anywhere outside build directories.
* **Placeholders** — no `TODO`, `FIXME`, `XXX`, `NOT IMPLEMENTED`,
  `PLACEHOLDER` or `STUB` in production sources, so no claimed feature can be
  a stub.
* **Catalogue completeness** — every diagnostic code and every registered
  option has a message key in both maintained locales. This is what stops help
  from describing an option the parser does not accept, and stops a diagnostic
  from rendering as a bare key.
* **Version consistency** — the engine version the program reports matches the
  manifest pin, and the changelog records the version being built.
* **Documentation presence** — every document the project promises exists.
* **Gap traceability** — every gap identifier in `doc/posix-conformance.md`
  has a test that reproduces it.
* **Layering** — only the packages doc/architecture.md names may import
  sedlib, the message catalogue, the terminal, Ada.Text_IO or the argument
  vector; the command line and the I/O layers import none of them.
* **Template arguments** — every placeholder in a message template is an
  argument the diagnostic actually supplies.
* **Traceability** — every requirement, command and diagnostic code cites a
  test, and every cited test exists.
* **Generated files** — nothing under obj, bin, lib, alire, config or dist is
  tracked in git.
* **Proof** — the declared SPARK scope: the status accumulator including its
  monotonicity contract, and the source map arithmetic that decides which
  script source a diagnostic names.

## Clean safety

`clean` removes only known project-owned directories, only when they exist,
and only when the resolved path lies inside the repository root. It never
recurses from an unvalidated path.

## Release gate

`release` runs the whole of `verify` and then requires the version to still be
a prerelease while `doc/posix-conformance.md` records open gaps. The project
cannot describe itself as a finished POSIX release by accident.

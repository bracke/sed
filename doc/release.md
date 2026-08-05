# Release

## Versioning

There is one authoritative version: `version` in the root `alire.toml`. Alire
generates `Sed_Config.Crate_Version` from it, `Sed.Version.Value` renames
that, and `sed --version` prints it. There is no second place to update and no
way for the manifest, the executable and the artifacts to disagree.

Nothing generated carries a timestamp, host name, user name, absolute path or
any other value that would make two builds of the same source differ.

`Sed.Version.Engine_Version` records the `sedlib` version this build was
compiled against; `sed_tools verify` checks it against the manifest pin.

## Prerelease policy

The version stays a prerelease until the program has been exercised beyond
its own suite. `sed_tools release` enforces this: it fails on a
non-prerelease version. Any conformance gap recorded in
`doc/posix-conformance.md` is a further reason to stay one.

The current release is `0.1.0-dev` with no open gaps. It stays a prerelease
because it is the first snapshot of a new program.

## The gate

```sh
cd tests && ./bin/sed_tools release
```

which runs, in order: build both crates, run the AUnit suite, check
administrative output, audit forbidden files and placeholders, check catalogue
completeness for every diagnostic code and option in every locale, check
version and changelog consistency, check that every promised document exists,
check that every documented gap has a reproducing test, and apply the
prerelease policy. Any failure fails the gate.

## Installation

```sh
alr install
```

installs `bin/sed` and `share/sed/messages/catalog.txt`. The executable
resolves its catalogue at `../share/sed/messages/catalog.txt` relative to its
own location, so an installed program never reads from the source tree, a
build directory, a test fixture or a developer-local path. The same relative
path works from the build tree, where `bin/` and `share/` are siblings.

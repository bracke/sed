# Security

## sed is not a sandbox

A sed script is a program, and running one runs it. A script may:

* read any file the caller can read, through `r`;
* create or truncate any file the caller can write, through `w` and `s///w`;
* produce very large output;
* consume substantial memory and CPU;
* loop forever through `b` and `t`.

Run untrusted scripts only with privileges you are willing for the script to
have. This program adds no shell-execution extension, and it never passes a
path through a shell: paths reach the host exactly as the user wrote them.

## Terminal injection

Values that reach a diagnostic come from outside the program — paths, option
spellings, labels, regular-expression fragments, script excerpts. All of them
are escaped before they become message arguments: control characters, DEL and
the escape character become backslash escapes, and bytes that are not
well-formed UTF-8 become `\xHH`. A crafted path cannot emit escape sequences,
move the cursor or recolour later output. The raw value is what reaches the
filesystem; only the displayed form is escaped.

## What is not disclosed

Diagnostics never include the pattern space or the hold space, so editing a
file with sensitive content does not leak that content into a log through an
error message. They also never include Ada package names, exception names,
memory addresses or tracebacks.

`SED_DEBUG` enables a development mode that adds exception information to the
internal-error diagnostic. It is off unless asked for and changes nothing
else.

## No side channels

The program creates no log file, no telemetry, no network traffic and no
persistent user configuration. It reads only the environment variables
documented in `doc/diagnostics-and-localization.md` and
`doc/command-line.md`.

## Resource exhaustion

Bounds exist but are set high enough that ordinary use never meets them; a
command-line stream editor that refused a large file would be useless.
Exceeding one is deliberate, deterministic and reported as a structured
`Resource_Exhausted` diagnostic with the limit, the observed value and the
permitted value — never a crash and never a silent truncation.

An unbounded script (`:x;bx`) runs until the engine's instruction bound is
reached or the process is interrupted. That is the same behaviour any sed has.

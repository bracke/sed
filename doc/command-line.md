# Command line

## Forms

```
sed [-n] script [file...]
sed [-n] -e script [-e script]... [-f script_file]... [file...]
sed [-n] -f script_file [-e script]... [-f script_file]... [file...]
```

## Options

| Option | Argument | Status | Meaning |
| --- | --- | --- | --- |
| `-n` | none | POSIX | Suppress the automatic print at the end of each cycle. Repeating it is harmless. |
| `-e script` | required | POSIX | Add script text. May be attached (`-e'p'`) or clustered (`-ne 'p'`). |
| `-f script_file` | required | POSIX | Add the contents of a file. Same attachment rules. |
| `--help` | none | implementation | Write help to standard output and exit 0. |
| `--version` | none | implementation | Write version information to standard output and exit 0. |
| `--color=auto\|always\|never` | required, attached | implementation | Style diagnostics only. |
| `--` | none | POSIX | End option processing. |

`--help` and `--version` stop option processing where they appear, so nothing
after them is loaded or opened. `--color` takes its argument only in attached
form, so a bare `--color` is a missing-argument failure rather than something
that swallows the next operand.

GNU options `-i -E -r -z -s -u --posix --regexp-extended --sandbox
--follow-symlinks` are not implemented and are reported as unknown options.

## Positional script

When no `-e` and no `-f` is present, the first operand is the script and the
rest are input files. When either option is present, every operand is an input
file. A script beginning with `-` must be given after `--`.

## Operands and streams

Input operands form one logical stream. `-` names standard input and takes its
place in operand order; repeating it does not rewind. With no operand,
standard input is read.

Standard output carries program data only: the automatic print, `p`, `P`, `=`,
`l`, `a`, `i`, `c` and `r` output. It never carries a diagnostic, a severity
label, a hint or an escape sequence. Help and version also go to standard
output, but only in administrative mode, before any execution.

Standard error carries localized diagnostics only.

## Exit status

| Status | Meaning |
| --- | --- |
| 0 | Success, or `--help`, or `--version` |
| 1 | Script loading, compilation, input, output or execution failure |
| 2 | Invalid invocation |
| 3 | Unexpected internal failure |

POSIX requires only "0 on success, greater than 0 on error"; the split above
is implementation-defined. Statuses accumulate monotonically in the documented
precedence order, so a later success never erases an earlier failure.

## Colour

`auto` styles only when the destination is a terminal and `NO_COLOR` is unset;
`always` styles unconditionally, and an explicit `--color=always` outranks
`NO_COLOR`; `never` never styles. Styling changes only the bytes of a
diagnostic, never its information, never message selection, never status, and
never program data.

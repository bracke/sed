# Examples

Small POSIX sed scripts, each usable directly:

```sh
sed -f examples/double-space.sed FILE
```

| Script | Does |
| --- | --- |
| `double-space.sed` | Puts a blank line after every line |
| `reverse-lines.sed` | Reverses line order, as `tac` does |
| `squeeze-blank.sed` | Collapses runs of blank lines into one |
| `strip-trailing-blanks.sed` | Removes trailing spaces |

Every one is POSIX: no GNU extension, and no construct this program rejects.

These are executable documentation rather than prose. `EXAMPLE-001` runs each
of them against `tests/fixtures/input.txt` and compares the result with the
recorded output beside it, so an example that stopped working, or whose
behaviour changed, fails the suite instead of quietly misleading a reader.

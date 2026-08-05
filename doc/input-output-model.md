# Input and output model

## Bytes, not text

Every stream carries octets. `String` is the byte vector because `Character`
is one octet on the supported platforms. Nothing converts encodings,
translates line endings or interprets content. Files are read and written
through `Ada.Streams.Stream_IO` rather than `Ada.Text_IO` precisely because
Stream_IO performs no translation.

The supported input domain is therefore arbitrary bytes, including embedded
NUL, invalid UTF-8 and very long lines. The engine is configured for byte mode
with invalid UTF-8 treated as bytes, so a byte sequence that is not valid text
is transformed rather than rejected.

## Records

A record is the bytes up to, but not including, the next LF. A CR before that
LF is ordinary data and is preserved; this program does not do CRLF
translation. A file whose last byte is not LF yields a final record marked as
unterminated. A file ending exactly at an LF yields no extra empty record, and
an empty file yields no record at all.

## The logical stream

Every input operand contributes to one stream:

* Operands are opened lazily and in order, so an early `q` does not open files
  the script never reads and a blocking special file is not touched early.
* Global line numbers continue across operands and never reset.
* A local line number per operand is kept for diagnostics.
* Exactly one delivered record is marked as the final record of the whole
  stream.

Deciding which record is final requires one record of lookahead: the last
record of a file is only final if no later operand produces data. Because the
engine performs its own lookahead for `$` on top of this stream, the program
may read up to two records ahead of the one being processed. That is
observable only for interactive or FIFO input, and matches what any sed must
do to implement `$` at all.

## Newlines on output

An unterminated write can only legitimately be the last thing the program
emits. The standard-output writer therefore remembers an unterminated write
and, if anything follows it, supplies the separator that write omitted. The
result is that lines never run together, and the output stream ends exactly as
the input did: `printf 'a' | sed p` produces `a\na` with no trailing newline.

## Failure policy

Opening, reading, writing, flushing and closing all report structured results.
End of data is a status, not an exception.

* An unreadable named operand is reported, the run is marked as a processing
  failure, and later operands are still processed.
* A standard-input read failure ends the stream: there is no later position to
  recover to.
* A standard-output write or flush failure is fatal, and only the first one is
  reported — a closed pipe would otherwise produce one diagnostic per record.
* A `w` destination failure is fatal and reported honestly, with no claim that
  anything was rolled back.

## Platform scope

The guarantees above are verified on Linux and are expected to hold on other
POSIX-like systems. On Windows the standard streams do not carry octets
natively, so the byte-exactness claim is not made there; that platform is out
of scope for this release.

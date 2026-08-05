--  Escaping of untrusted values used in diagnostics.
--
--  Paths, option spellings, labels, regular-expression fragments and script
--  excerpts all originate outside the program. Rendering them verbatim on a
--  terminal would let a crafted value emit escape sequences, move the cursor
--  or recolour later output. Everything that reaches a rendered diagnostic
--  passes through here first.
--
--  Escaping is a presentation concern only. Values used for real filesystem
--  operations are always the raw ones.
package Sed.Diagnostics.Quoting is

   --  Return Value with control characters and ill-formed bytes escaped.
   --
   --  C0 controls, DEL and the escape character become backslash escapes, a
   --  backslash is doubled, and bytes that do not form a well-formed UTF-8
   --  sequence become \xHH. Well-formed multi-byte UTF-8 passes through so
   --  that non-ASCII paths stay readable.
   --
   --  @param Value Raw untrusted value.
   --  @return Value safe to write to a terminal.
   function Escape (Value : String) return String;

   --  Return Escape (Value) wrapped in single quotes.
   --
   --  Used where a value has to be visually delimited, such as an option
   --  spelling or an empty path, so that leading or trailing spaces and empty
   --  values remain visible.
   --
   --  @param Value Raw untrusted value.
   --  @return Quoted, escaped value.
   function Quoted (Value : String) return String
     with Post => Quoted'Result'Length >= 2;

   --  Whether Value would pass through Escape unchanged.
   --
   --  @param Value Raw value to test.
   --  @return True when Value contains nothing that needs escaping.
   function Is_Safe (Value : String) return Boolean
     with Post => Is_Safe'Result = (Escape (Value) = Value);

end Sed.Diagnostics.Quoting;

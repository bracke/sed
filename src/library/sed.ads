--  Root of the sed command-line stream editor.
--
--  This package carries only process identity that every layer may reference.
--  It deliberately holds no state and depends on nothing, so that any child
--  unit may with it without creating a dependency cycle.
--
--  The sed language itself is never parsed or executed here: sedlib is the
--  sole sed-language parser and execution engine, and regexp is the sole
--  regular-expression engine. This hierarchy owns invocation handling,
--  script provenance, input sequencing, output, diagnostics and status.
package Sed is

   pragma Pure;

   --  Stable program name used in diagnostics and usage output.
   --
   --  This is an approved non-localized literal: it names the executable
   --  rather than addressing the user, and must be identical in every locale.
   Program_Name : constant String := "sed";

   --  Signed line counter wide enough for very large logical input streams.
   --
   --  Global input line numbers, script line numbers and column numbers all
   --  use this type so that no counter silently wraps on a 32-bit range.
   type Line_Count is range -2 ** 63 .. 2 ** 63 - 1;

   subtype Line_Number is Line_Count range 0 .. Line_Count'Last;

   --  Zero means "no line information", so line numbers proper start at one.
   subtype Positive_Line_Number is Line_Count range 1 .. Line_Count'Last;

end Sed;

with Sed.IO;

--  Loading of -f script files into a source set.
--
--  Inline expressions need no loading and are appended directly through
--  Sed.Scripts.Append; only file sources come through here. Every script file
--  is read completely before compilation starts, so an unreadable -f file is
--  fatal before any input operand is opened and before any w destination is
--  created.
--
--  This unit depends on the I/O abstraction and diagnostics only. It knows
--  nothing about command-line parsing, sedlib or message catalogues.
package Sed.Scripts.Loading is

   --  Read a script file and append it to the set as one source unit.
   --
   --  On failure the set is left unchanged and Diagnostic describes the
   --  failure with the path that could not be read.
   --
   --  @param Set Set to extend.
   --  @param Files Filesystem to read through.
   --  @param Path Script file path exactly as supplied.
   --  @param Occurrence 1-based index among -f occurrences.
   --  @param Argument_Index Originating argument-list index.
   --  @param Ordinal 1-based position in command-line order.
   --  @param Diagnostic Structured failure, meaningful when Success is False.
   --  @param Success True when the file was read and appended.
   procedure Load_File
     (Set : in out Source_Set;
      Files : in out Sed.IO.Filesystem_Interface'Class;
      Path : String;
      Occurrence : Positive;
      Argument_Index : Positive;
      Ordinal : Positive;
      Diagnostic : out Sed.Diagnostics.Diagnostic;
      Success : out Boolean);

end Sed.Scripts.Loading;

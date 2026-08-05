with Sed.Diagnostics;
with Sed.Input.Logical_Stream;
with Sed.IO;
with Sed.Output.Named_Files;
with Sed.Output.Standard;
with Sed.Scripts.Compilation;

--  Execution of a compiled sed program.
--
--  This layer owns no sed semantics. Pattern and hold spaces, the cycle,
--  automatic printing, address ranges, branching and substitution state all
--  live in sedlib; what happens here is the wiring of that engine to the
--  program's real input stream, standard output, w destinations and r files,
--  and the translation of whatever the engine reports back into sed
--  diagnostics.
package Sed.Execution is

   type Outcome is record
      Succeeded : Boolean := False;
      Diagnostics : Sed.Diagnostics.Diagnostic_List :=
        Sed.Diagnostics.Empty_List;
      --  Lines the engine consumed from the logical stream.
      Lines_Read : Line_Count := 0;
   end record;

   --  Run a compiled program over the logical input stream.
   --
   --  Automatic printing is suppressed exactly when -n was given; explicit
   --  output commands stay active either way, because -n suppresses only the
   --  end-of-cycle print.
   --
   --  @param Program Compiled program to execute.
   --  @param Suppress_Automatic_Output True when -n was given.
   --  @param Source Logical input stream over every operand.
   --  @param Target Standard output writer for program data.
   --  @param Named Registry of w destinations, already created.
   --  @param Files Filesystem used to read r files.
   --  @param Result Structured outcome.
   procedure Run
     (Program : Sed.Scripts.Compilation.Compiled_Program;
      Suppress_Automatic_Output : Boolean;
      Source : not null access Sed.Input.Logical_Stream.Stream;
      Target : not null access Sed.Output.Standard.Writer;
      Named : not null access Sed.Output.Named_Files.Registry;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Result : out Outcome)
     with Pre => Sed.Scripts.Compilation.Is_Valid (Program);

end Sed.Execution;

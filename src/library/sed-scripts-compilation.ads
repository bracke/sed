private with Ada.Containers.Indefinite_Vectors;
private with Sedlib.Programs;

--  Compilation adapter over sedlib.
--
--  This is one of only two units that name sedlib at all. It hands the
--  combined script to Sedlib.Compilation, translates every sedlib compile
--  diagnostic into a Sed diagnostic located in the originating source unit,
--  and exposes the compiled program plus the write destinations it names.
--
--  It depends on script sources and diagnostics. It deliberately does not
--  depend on command-line parsing, terminal styling, message catalogues or
--  process streams.
package Sed.Scripts.Compilation is

   type Compiled_Program is private;

   --  Compile the combined script of a source set.
   --
   --  Diagnostics carry the source unit, line and column of the offending
   --  byte, so a failure in the second -e expression is reported against that
   --  expression and not against a concatenation the user never wrote.
   --
   --  @param Set Ordered script sources.
   --  @param Program Compiled program, valid only when Success is True.
   --  @param Diagnostics Every diagnostic sedlib produced, translated.
   --  @param Success True when the script compiled without errors.
   procedure Compile
     (Set : Source_Set;
      Program : out Compiled_Program;
      Diagnostics : out Sed.Diagnostics.Diagnostic_List;
      Success : out Boolean);

   --  @param Item Program to inspect.
   --  @return True when the program can be executed.
   function Is_Valid (Item : Compiled_Program) return Boolean;

   --  Number of distinct files the script writes to.
   --
   --  Destinations come from the compiled program rather than from a second
   --  parse of the script, which is what lets every w target be created once,
   --  before execution, without the command line understanding sed syntax.
   --
   --  @param Item Program to inspect.
   --  @return Count of distinct write destinations.
   function Write_Destination_Count (Item : Compiled_Program) return Natural;

   --  @param Item Program to inspect.
   --  @param Index 1-based destination position, in first-appearance order.
   --  @return Destination path exactly as written in the script.
   function Write_Destination
     (Item : Compiled_Program; Index : Positive) return String
     with Pre => Index <= Write_Destination_Count (Item);

private

   package Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Compiled_Program is record
      Valid : Boolean := False;
      --  The compiled sedlib program. Sedlib programs are ordinary values, so
      --  this record owns its copy and needs no explicit finalization.
      Program : Sedlib.Programs.Program := Sedlib.Programs.Invalid_Program;
      Destinations : Name_Vectors.Vector := Name_Vectors.Empty_Vector;
   end record;

end Sed.Scripts.Compilation;

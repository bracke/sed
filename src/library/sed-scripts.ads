private with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Sed.Diagnostics;

--  Ordered sed script sources and their provenance.
--
--  POSIX defines the script as the concatenation of every -e argument and
--  every -f file, in command-line order, separated by newlines. This package
--  performs exactly that concatenation and, at the same time, records where
--  every byte of the result came from.
--
--  The concatenation is therefore not a loss of information: Locate maps any
--  byte offset in the combined script back to the originating source unit and
--  to a line and column inside that unit, which is what lets a diagnostic say
--  "rules.sed:12:8" or "command line expression 2" precisely.
--
--  Each -e, -f or positional occurrence is its own unit. Units never merge:
--  a newline always separates one from the next, so "-e 's/a/b/' -e 'p'"
--  cannot become "s/a/b/p", while "-e 'a\' -e 'text'" still forms the single
--  multiline text command POSIX defines.
package Sed.Scripts is

   package U renames Ada.Strings.Unbounded;

   type Source_Id is new Positive;

   type Source_Kind is (Inline_Expression, Script_File);

   type Source_Unit is record
      Id : Source_Id := 1;
      Kind : Source_Kind := Inline_Expression;
      --  Script file path exactly as supplied; empty for inline expressions.
      Path : U.Unbounded_String := U.Null_Unbounded_String;
      --  1-based index among units of the same kind, used for the localized
      --  "command line expression N" label.
      Occurrence : Positive := 1;
      --  Originating argument-list index.
      Argument_Index : Positive := 1;
      --  1-based position in overall command-line order.
      Ordinal : Positive := 1;
      --  True for the positional script operand rather than an option.
      Positional : Boolean := False;
      --  Exact bytes accepted from the user, before newline normalization.
      Content : U.Unbounded_String := U.Null_Unbounded_String;
      --  0-based offset of this unit's first byte in the combined script.
      Start_Offset : Natural := 0;
      --  Number of bytes this unit occupies in the combined script, including
      --  a separator newline synthesized to keep units apart.
      Span : Natural := 0;
      --  1-based line of this unit's first byte in the combined script.
      Start_Line : Positive_Line_Number := 1;
      --  Lines this unit occupies in the combined script.
      Line_Span : Line_Number := 0;
   end record;

   type Source_Set is private;

   Empty_Set : constant Source_Set;

   --  Append one script source unit, extending the combined script.
   --
   --  A newline is synthesized after the unit when its content does not
   --  already end with one, so that units can never run together and every
   --  unit begins at column one of a fresh line.
   --
   --  @param Set Set to extend.
   --  @param Kind Whether the unit came from -e or from -f.
   --  @param Content Exact script bytes of this unit.
   --  @param Path Script file path; empty for inline expressions.
   --  @param Occurrence 1-based index among units of the same kind.
   --  @param Argument_Index Originating argument-list index.
   --  @param Ordinal 1-based position in command-line order.
   --  @param Positional True for the positional script operand.
   procedure Append
     (Set : in out Source_Set;
      Kind : Source_Kind;
      Content : String;
      Path : String := "";
      Occurrence : Positive := 1;
      Argument_Index : Positive := 1;
      Ordinal : Positive := 1;
      Positional : Boolean := False)
     with Post => Count (Set) = Count (Set)'Old + 1;

   --  @param Set Set to inspect.
   --  @return Number of source units.
   function Count (Set : Source_Set) return Natural;

   --  @param Set Set to inspect.
   --  @param Index 1-based unit position in command-line order.
   --  @return The source unit.
   function Unit (Set : Source_Set; Index : Positive) return Source_Unit
     with Pre => Index <= Count (Set);

   --  The complete script text handed to sedlib.
   --
   --  @param Set Set to inspect.
   --  @return Concatenated script, newline-separated by unit.
   function Combined_Text (Set : Source_Set) return String;

   --  Map a byte offset in the combined script back to its source unit.
   --
   --  @param Set Set to inspect.
   --  @param Offset 0-based offset into Combined_Text.
   --  @return 1-based unit index, or zero when the set is empty.
   function Unit_At (Set : Source_Set; Offset : Natural) return Natural
     with Post => Unit_At'Result <= Count (Set);

   --  Map a byte offset in the combined script to a renderable location.
   --
   --  A file unit yields a path location, an inline unit an expression
   --  location, both carrying the line and column within that unit rather
   --  than within the concatenation.
   --
   --  @param Set Set to inspect.
   --  @param Offset 0-based offset into Combined_Text.
   --  @return Source location for diagnostics.
   function Locate
     (Set : Source_Set;
      Offset : Natural) return Sed.Diagnostics.Source_Location;

private

   package Unit_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Source_Unit);

   type Source_Set is record
      Units : Unit_Vectors.Vector := Unit_Vectors.Empty_Vector;
      Text : U.Unbounded_String := U.Null_Unbounded_String;
      --  Line on which the next appended unit will start.
      Next_Line : Positive_Line_Number := 1;
   end record;

   Empty_Set : constant Source_Set :=
     (Units => Unit_Vectors.Empty_Vector,
      Text => U.Null_Unbounded_String,
      Next_Line => 1);

end Sed.Scripts;

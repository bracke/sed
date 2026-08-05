with Ada.Strings.Unbounded;

--  Vocabulary of the logical input stream.
--
--  Every input operand contributes to one logical stream: execution state,
--  address ranges and line numbering continue across operand boundaries, and
--  exactly one delivered line is the final line of the whole stream.
--
--  This package names input concepts only. It knows nothing about sed
--  commands, message catalogues or terminal styling.
package Sed.Input is

   package U renames Ada.Strings.Unbounded;

   type Operand_Kind is (Named_File, Standard_Input);

   type Operand is record
      Kind : Operand_Kind := Named_File;
      --  Operand text exactly as supplied; "-" for standard input.
      Name : U.Unbounded_String := U.Null_Unbounded_String;
   end record;

   type Record_Status is (Record_Available, End_Of_Input, Read_Failed);

   --  One delivered logical line.
   type Input_Line is record
      --  Exact bytes of the line, without its terminator.
      Data : U.Unbounded_String := U.Null_Unbounded_String;
      --  False for a final line that was not newline-terminated.
      Has_Terminator : Boolean := False;
      --  Position in the whole logical stream; never decreases and never
      --  resets at an operand boundary.
      Global_Line : Positive_Line_Number := 1;
      --  Position within the operand this line came from.
      Local_Line : Positive_Line_Number := 1;
      --  Operand this line came from.
      Source_Name : U.Unbounded_String := U.Null_Unbounded_String;
      Source_Kind : Operand_Kind := Named_File;
      --  True only for the final line of the complete logical stream.
      Is_Final : Boolean := False;
   end record;

end Sed.Input;

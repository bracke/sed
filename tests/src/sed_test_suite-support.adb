with Ada.Directories;
with Sed.Application;
with Sed.Command_Line.Arguments;

package body Sed_Test_Suite.Support is

   -------
   -- A --
   -------

   function A (Item : String) return U.Unbounded_String is
   begin
      return U.To_Unbounded_String (Item);
   end A;

   ------------------
   -- Catalog_Path --
   ------------------

   function Catalog_Path return String is
      Candidates : constant array (1 .. 3) of U.Unbounded_String :=
        [U.To_Unbounded_String ("../share/sed/messages/catalog.txt"),
         U.To_Unbounded_String ("share/sed/messages/catalog.txt"),
         U.To_Unbounded_String ("../../share/sed/messages/catalog.txt")];
   begin
      for Candidate of Candidates loop
         declare
            Path : constant String := U.To_String (Candidate);
         begin
            if Ada.Directories.Exists (Path) then
               return Path;
            end if;
         end;
      end loop;

      return "";
   exception
      when others =>
         return "";
   end Catalog_Path;

   -----------------
   -- Environment --
   -----------------

   function Environment
     (Locale : String := "";
      Error_Is_Terminal : Boolean := False)
      return Sed.Environment.Process_Environment is
   begin
      return
        (Locale => U.To_Unbounded_String (Locale),
         No_Color => False,
         Catalog_Path => U.To_Unbounded_String (Catalog_Path),
         Standard_Output_Is_Terminal => False,
         Standard_Error_Is_Terminal => Error_Is_Terminal,
         Development_Diagnostics => False);
   end Environment;

   ---------
   -- Run --
   ---------

   function Run
     (Arguments : Argument_Array;
      Files : in out Doubles.Memory_Filesystem;
      Standard_Input : String := "";
      Locale : String := "";
      Error_Is_Terminal : Boolean := False) return Run_Result
   is
      List : Sed.Command_Line.Arguments.Fixed_List;
      Input : Doubles.Memory_Input;
      Output_Stream : Doubles.Memory_Output;
      Error_Stream : Doubles.Memory_Output;
      Result : Run_Result;
   begin
      for Item of Arguments loop
         Sed.Command_Line.Arguments.Append (List, U.To_String (Item));
      end loop;

      Doubles.Set_Text (Input, Standard_Input);
      Doubles.Set_Terminal (Error_Stream, Error_Is_Terminal);

      Result.Outcome :=
        Sed.Application.Execute
          (Arguments => List,
           Standard_In => Input,
           Standard_Out => Output_Stream,
           Standard_Err => Error_Stream,
           Filesystem => Files,
           Context => Environment (Locale, Error_Is_Terminal));

      Result.Exit_Status := Sed.Status.Status_Of (Result.Outcome);
      Result.Output := U.To_Unbounded_String (Doubles.Text (Output_Stream));
      Result.Errors := U.To_Unbounded_String (Doubles.Text (Error_Stream));
      return Result;
   end Run;

   ---------
   -- Run --
   ---------

   function Run
     (Arguments : Argument_Array;
      Standard_Input : String := "";
      Locale : String := "") return Run_Result
   is
      Files : Doubles.Memory_Filesystem;
   begin
      return Run (Arguments, Files, Standard_Input, Locale);
   end Run;

   ------------
   -- Output --
   ------------

   function Output (Item : Run_Result) return String is
   begin
      return U.To_String (Item.Output);
   end Output;

   ------------
   -- Errors --
   ------------

   function Errors (Item : Run_Result) return String is
   begin
      return U.To_String (Item.Errors);
   end Errors;

   --------------
   -- Contains --
   --------------

   function Contains (Haystack : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 then
         return True;
      end if;

      if Needle'Length > Haystack'Length then
         return False;
      end if;

      for Start in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
         if Haystack (Start .. Start + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

end Sed_Test_Suite.Support;

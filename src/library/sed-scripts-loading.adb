package body Sed.Scripts.Loading is

   package D renames Sed.Diagnostics;

   use type Sed.IO.IO_Status;

   ---------------
   -- Load_File --
   ---------------

   procedure Load_File
     (Set : in out Source_Set;
      Files : in out Sed.IO.Filesystem_Interface'Class;
      Path : String;
      Occurrence : Positive;
      Argument_Index : Positive;
      Ordinal : Positive;
      Diagnostic : out D.Diagnostic;
      Success : out Boolean)
   is
      Content : U.Unbounded_String;
      Result : Sed.IO.IO_Result;
   begin
      Diagnostic := D.Make (D.Script_File_Open_Failed);
      Success := False;

      Files.Read_Whole_File (Path, Content, Result);

      if Sed.IO.Is_Failure (Result) then
         --  A path that could not be opened at all and one that failed while
         --  being read are different faults, and the user can act on the
         --  difference.
         declare
            Code : constant D.Diagnostic_Code :=
              (if Result.Status = Sed.IO.IO_Failure
               then D.Script_File_Read_Failed
               else D.Script_File_Open_Failed);
            Item : D.Diagnostic := D.Make (Code, D.Path_At (Path));
         begin
            D.Set (Item, D.Path, Path);

            if U.Length (Result.Detail) > 0 then
               D.Set (Item, D.Detail, U.To_String (Result.Detail));
            end if;

            Diagnostic := Item;
         end;

         return;
      end if;

      Append
        (Set            => Set,
         Kind           => Script_File,
         Content        => U.To_String (Content),
         Path           => Path,
         Occurrence     => Occurrence,
         Argument_Index => Argument_Index,
         Ordinal        => Ordinal,
         Positional     => False);

      Success := True;
   end Load_File;

end Sed.Scripts.Loading;

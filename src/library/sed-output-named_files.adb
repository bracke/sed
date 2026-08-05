package body Sed.Output.Named_Files is

   package D renames Sed.Diagnostics;
   package U renames Sed.IO.U;

   --  Index of a registered destination, or zero.
   function Index_Of (Self : Registry; Path : String) return Natural;

   --  Record a destination failure once.
   procedure Report
     (Self : in out Registry;
      Position : Natural;
      Code : D.Diagnostic_Code;
      Path : String;
      Detail : String);

   --------------
   -- Index_Of --
   --------------

   function Index_Of (Self : Registry; Path : String) return Natural is
   begin
      for Position in 1 .. Natural (Self.Items.Length) loop
         if U.To_String (Self.Items (Position).Path) = Path then
            return Position;
         end if;
      end loop;

      return 0;
   end Index_Of;

   ------------
   -- Report --
   ------------

   procedure Report
     (Self : in out Registry;
      Position : Natural;
      Code : D.Diagnostic_Code;
      Path : String;
      Detail : String)
   is
      Item : D.Diagnostic := D.Make (Code, D.Path_At (Path));
   begin
      if Position /= 0 then
         if Self.Items (Position).Broken then
            return;
         end if;

         declare
            Updated : Destination := Self.Items (Position);
         begin
            Updated.Broken := True;
            Self.Items.Replace_Element (Position, Updated);
         end;
      end if;

      D.Set (Item, D.Path, Path);

      if Detail'Length > 0 then
         D.Set (Item, D.Detail, Detail);
      end if;

      D.Append (Self.Diagnostics, Item);
   end Report;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : in out Registry;
      Files : not null access Sed.IO.Filesystem_Interface'Class) is
   begin
      Self.Files := Files;
      Self.Items := Destination_Vectors.Empty_Vector;
      Self.Diagnostics := D.Empty_List;
      Self.Closed := False;
   end Initialize;

   ------------------------
   -- Create_Destination --
   ------------------------

   procedure Create_Destination
     (Self : in out Registry;
      Path : String;
      Success : out Boolean)
   is
      Existing : constant Natural := Index_Of (Self, Path);
      Handle : Sed.IO.File_Handle;
      Result : Sed.IO.IO_Result;
   begin
      if Existing /= 0 then
         --  Already created: never truncate a destination a second time.
         Success := not Self.Items (Existing).Broken;
         return;
      end if;

      Self.Files.Create_Output (Path, Handle, Result);

      if Sed.IO.Is_Failure (Result) then
         Self.Items.Append
           (Destination'
              (Path => U.To_Unbounded_String (Path),
               Handle => Sed.IO.Invalid_Handle,
               Broken => False));

         Report
           (Self,
            Natural (Self.Items.Length),
            D.Named_Output_Open_Failed,
            Path,
            U.To_String (Result.Detail));

         Success := False;
         return;
      end if;

      Self.Items.Append
        (Destination'
           (Path => U.To_Unbounded_String (Path),
            Handle => Handle,
            Broken => False));

      Success := True;
   end Create_Destination;

   -----------
   -- Write --
   -----------

   procedure Write
     (Self : in out Registry;
      Path : String;
      Data : String;
      Terminator : Terminator_Policy;
      Success : out Boolean)
   is
      Position : Natural := Index_Of (Self, Path);
      Result : Sed.IO.IO_Result;
   begin
      Success := False;

      if Position = 0 then
         --  A destination the compiled program did not announce. Creating it
         --  here keeps execution correct rather than dropping output.
         declare
            Created : Boolean;
         begin
            Create_Destination (Self, Path, Created);
            Position := Index_Of (Self, Path);

            if not Created then
               return;
            end if;
         end;
      end if;

      if Self.Items (Position).Broken
        or else not Sed.IO.Is_Open (Self.Items (Position).Handle)
      then
         return;
      end if;

      if Data'Length > 0 then
         Self.Files.Write (Self.Items (Position).Handle, Data, Result);

         if Sed.IO.Is_Failure (Result) then
            Report
              (Self,
               Position,
               D.Named_Output_Write_Failed,
               Path,
               U.To_String (Result.Detail));
            return;
         end if;
      end if;

      if Terminator = With_Terminator then
         Self.Files.Write
           (Self.Items (Position).Handle, [1 => ASCII.LF], Result);

         if Sed.IO.Is_Failure (Result) then
            Report
              (Self,
               Position,
               D.Named_Output_Write_Failed,
               Path,
               U.To_String (Result.Detail));
            return;
         end if;
      end if;

      Success := True;
   end Write;

   ---------------
   -- Close_All --
   ---------------

   procedure Close_All (Self : in out Registry; Success : out Boolean) is
   begin
      Success := True;

      if Self.Closed then
         return;
      end if;

      Self.Closed := True;

      for Position in 1 .. Natural (Self.Items.Length) loop
         declare
            Item : Destination := Self.Items (Position);
            Result : Sed.IO.IO_Result;
         begin
            if Sed.IO.Is_Open (Item.Handle) and then Self.Files /= null then
               Self.Files.Close_Output (Item.Handle, Result);
               Self.Items.Replace_Element (Position, Item);

               if Sed.IO.Is_Failure (Result) then
                  --  A close fault can mean buffered lines never reached the
                  --  file, so it is reported rather than silently dropped.
                  Report
                    (Self,
                     Position,
                     D.Named_Output_Write_Failed,
                     U.To_String (Item.Path),
                     U.To_String (Result.Detail));
                  Success := False;
               end if;
            end if;
         end;
      end loop;
   end Close_All;

   ----------------------
   -- Take_Diagnostics --
   ----------------------

   procedure Take_Diagnostics
     (Self : in out Registry;
      Into : out D.Diagnostic_List) is
   begin
      Into := Self.Diagnostics;
      Self.Diagnostics := D.Empty_List;
   end Take_Diagnostics;

   -----------------------
   -- Destination_Count --
   -----------------------

   function Destination_Count (Self : Registry) return Natural is
   begin
      return Natural (Self.Items.Length);
   end Destination_Count;

   -------------------
   -- Is_Registered --
   -------------------

   function Is_Registered (Self : Registry; Path : String) return Boolean is
   begin
      return Index_Of (Self, Path) /= 0;
   end Is_Registered;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Registry) is
      Ignored : Boolean;
   begin
      Close_All (Self, Ignored);
   end Finalize;

end Sed.Output.Named_Files;

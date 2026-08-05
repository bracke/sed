package body Sed_Test_Suite.Doubles is

   use type Sed.IO.File_Handle;

   --  Index of the entry naming Path, or zero.
   function Index_Of (Self : Memory_Filesystem; Path : String) return Natural;

   --  Index of the entry naming Path, creating a placeholder when absent.
   procedure Ensure_Entry
     (Self : in out Memory_Filesystem;
      Path : String;
      Index : out Positive);

   --  Reserve a handle slot.
   procedure Claim_Handle
     (Self : in out Memory_Filesystem;
      Item : Handle_Record;
      Handle : out Sed.IO.File_Handle);

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self : in out Memory_Output;
      Data : String;
      Result : out Sed.IO.IO_Result) is
   begin
      if U.Length (Self.Buffer) >= Self.Write_Limit then
         Result := Sed.IO.Failure (Sed.IO.IO_Failure, "injected write failure");
         return;
      end if;

      U.Append (Self.Buffer, Data);
      Result := Sed.IO.Success_Result;
   end Write;

   -----------
   -- Flush --
   -----------

   overriding procedure Flush
     (Self : in out Memory_Output;
      Result : out Sed.IO.IO_Result) is
   begin
      if Self.Flush_Fails then
         Result := Sed.IO.Failure (Sed.IO.IO_Failure, "injected flush failure");
         return;
      end if;

      Self.Flushes := Self.Flushes + 1;
      Result := Sed.IO.Success_Result;
   end Flush;

   -----------------
   -- Is_Terminal --
   -----------------

   overriding function Is_Terminal (Self : Memory_Output) return Boolean is
   begin
      return Self.Terminal;
   end Is_Terminal;

   ----------
   -- Text --
   ----------

   function Text (Self : Memory_Output) return String is
   begin
      return U.To_String (Self.Buffer);
   end Text;

   -----------------
   -- Flush_Count --
   -----------------

   function Flush_Count (Self : Memory_Output) return Natural is
   begin
      return Self.Flushes;
   end Flush_Count;

   ------------------
   -- Set_Terminal --
   ------------------

   procedure Set_Terminal (Self : in out Memory_Output; Value : Boolean) is
   begin
      Self.Terminal := Value;
   end Set_Terminal;

   ------------------------
   -- Fail_Writes_After --
   ------------------------

   procedure Fail_Writes_After
     (Self : in out Memory_Output; After_Bytes : Natural) is
   begin
      Self.Write_Limit := After_Bytes;
   end Fail_Writes_After;

   ----------------
   -- Fail_Flush --
   ----------------

   procedure Fail_Flush (Self : in out Memory_Output) is
   begin
      Self.Flush_Fails := True;
   end Fail_Flush;

   --------------
   -- Set_Text --
   --------------

   procedure Set_Text (Self : in out Memory_Input; Data : String) is
   begin
      Self.Buffer := U.To_Unbounded_String (Data);
      Self.Cursor := 0;
   end Set_Text;

   -----------------------
   -- Fail_Reads_After --
   -----------------------

   procedure Fail_Reads_After
     (Self : in out Memory_Input; After_Bytes : Natural) is
   begin
      Self.Read_Limit := After_Bytes;
   end Fail_Reads_After;

   ----------
   -- Read --
   ----------

   overriding procedure Read
     (Self : in out Memory_Input;
      Into : out String;
      Last : out Natural;
      Result : out Sed.IO.IO_Result)
   is
      Available : constant Natural := U.Length (Self.Buffer) - Self.Cursor;
   begin
      Into := [others => ASCII.NUL];
      Last := Into'First - 1;

      if Self.Cursor >= Self.Read_Limit then
         Result := Sed.IO.Failure (Sed.IO.IO_Failure, "injected read failure");
         return;
      end if;

      if Available = 0 then
         Result := (Status => Sed.IO.End_Of_Data, Detail => U.Null_Unbounded_String);
         return;
      end if;

      declare
         Count : constant Natural := Natural'Min (Available, Into'Length);
         Slice : constant String :=
           U.Slice (Self.Buffer, Self.Cursor + 1, Self.Cursor + Count);
      begin
         Into (Into'First .. Into'First + Count - 1) := Slice;
         Last := Into'First + Count - 1;
         Self.Cursor := Self.Cursor + Count;
      end;

      Result := Sed.IO.Success_Result;
   end Read;

   --------------
   -- Index_Of --
   --------------

   function Index_Of (Self : Memory_Filesystem; Path : String) return Natural is
   begin
      for Position in 1 .. Natural (Self.Entries.Length) loop
         if U.To_String (Self.Entries (Position).Path) = Path then
            return Position;
         end if;
      end loop;

      return 0;
   end Index_Of;

   ------------------
   -- Ensure_Entry --
   ------------------

   procedure Ensure_Entry
     (Self : in out Memory_Filesystem;
      Path : String;
      Index : out Positive)
   is
      Existing : constant Natural := Index_Of (Self, Path);
   begin
      if Existing /= 0 then
         Index := Existing;
         return;
      end if;

      Self.Entries.Append
        (Entry_Record'(Path => U.To_Unbounded_String (Path), others => <>));
      Index := Natural (Self.Entries.Length);
   end Ensure_Entry;

   ------------------
   -- Claim_Handle --
   ------------------

   procedure Claim_Handle
     (Self : in out Memory_Filesystem;
      Item : Handle_Record;
      Handle : out Sed.IO.File_Handle) is
   begin
      for Position in 1 .. Natural (Self.Handles.Length) loop
         if not Self.Handles (Position).Active then
            Self.Handles.Replace_Element (Position, Item);
            Handle := Sed.IO.To_Handle (Position);
            return;
         end if;
      end loop;

      Self.Handles.Append (Item);
      Handle := Sed.IO.To_Handle (Natural (Self.Handles.Length));
   end Claim_Handle;

   --------------
   -- Add_File --
   --------------

   procedure Add_File
     (Self : in out Memory_Filesystem;
      Path : String;
      Content : String)
   is
      Index : Positive;
   begin
      Ensure_Entry (Self, Path, Index);

      declare
         Item : Entry_Record := Self.Entries (Index);
      begin
         Item.Content := U.To_Unbounded_String (Content);
         Item.Exists := True;
         Self.Entries.Replace_Element (Index, Item);
      end;
   end Add_File;

   ------------
   -- Exists --
   ------------

   function Exists (Self : Memory_Filesystem; Path : String) return Boolean is
      Index : constant Natural := Index_Of (Self, Path);
   begin
      return Index /= 0 and then Self.Entries (Index).Exists;
   end Exists;

   -------------
   -- Content --
   -------------

   function Content (Self : Memory_Filesystem; Path : String) return String is
      Index : constant Natural := Index_Of (Self, Path);
   begin
      if Index = 0 then
         return "";
      end if;

      return U.To_String (Self.Entries (Index).Content);
   end Content;

   ---------------
   -- Fail_Open --
   ---------------

   procedure Fail_Open
     (Self : in out Memory_Filesystem;
      Path : String;
      Status : Sed.IO.Failure_Status := Sed.IO.Permission_Denied)
   is
      Index : Positive;
   begin
      Ensure_Entry (Self, Path, Index);

      declare
         Item : Entry_Record := Self.Entries (Index);
      begin
         Item.Open_Fails := True;
         Item.Open_Status := Status;
         Self.Entries.Replace_Element (Index, Item);
      end;
   end Fail_Open;

   ---------------
   -- Fail_Read --
   ---------------

   procedure Fail_Read (Self : in out Memory_Filesystem; Path : String) is
      Index : Positive;
   begin
      Ensure_Entry (Self, Path, Index);

      declare
         Item : Entry_Record := Self.Entries (Index);
      begin
         Item.Read_Fails := True;
         Self.Entries.Replace_Element (Index, Item);
      end;
   end Fail_Read;

   -----------------
   -- Fail_Create --
   -----------------

   procedure Fail_Create (Self : in out Memory_Filesystem; Path : String) is
      Index : Positive;
   begin
      Ensure_Entry (Self, Path, Index);

      declare
         Item : Entry_Record := Self.Entries (Index);
      begin
         Item.Create_Fails := True;
         Self.Entries.Replace_Element (Index, Item);
      end;
   end Fail_Create;

   ----------------
   -- Fail_Write --
   ----------------

   procedure Fail_Write (Self : in out Memory_Filesystem; Path : String) is
      Index : Positive;
   begin
      Ensure_Entry (Self, Path, Index);

      declare
         Item : Entry_Record := Self.Entries (Index);
      begin
         Item.Write_Fails := True;
         Self.Entries.Replace_Element (Index, Item);
      end;
   end Fail_Write;

   ------------------
   -- Create_Count --
   ------------------

   function Create_Count
     (Self : Memory_Filesystem; Path : String) return Natural
   is
      Index : constant Natural := Index_Of (Self, Path);
   begin
      if Index = 0 then
         return 0;
      end if;

      return Self.Entries (Index).Creates;
   end Create_Count;

   ----------------
   -- Open_Count --
   ----------------

   function Open_Count (Self : Memory_Filesystem) return Natural is
      Count : Natural := 0;
   begin
      for Item of Self.Handles loop
         if Item.Active then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Open_Count;

   ----------------
   -- Open_Input --
   ----------------

   overriding procedure Open_Input
     (Self : in out Memory_Filesystem;
      Path : String;
      Handle : out Sed.IO.File_Handle;
      Result : out Sed.IO.IO_Result)
   is
      Index : constant Natural := Index_Of (Self, Path);
   begin
      Handle := Sed.IO.Invalid_Handle;

      if Index = 0 or else not Self.Entries (Index).Exists then
         Result := Sed.IO.Failure (Sed.IO.Not_Found);
         return;
      end if;

      if Self.Entries (Index).Open_Fails then
         Result := Sed.IO.Failure (Self.Entries (Index).Open_Status);
         return;
      end if;

      Claim_Handle
        (Self,
         Handle_Record'
           (Active => True, Writing => False, Entry_Index => Index, Cursor => 0),
         Handle);

      Result := Sed.IO.Success_Result;
   end Open_Input;

   ----------
   -- Read --
   ----------

   overriding procedure Read
     (Self : in out Memory_Filesystem;
      Handle : Sed.IO.File_Handle;
      Into : out String;
      Last : out Natural;
      Result : out Sed.IO.IO_Result)
   is
      Position : constant Natural := Sed.IO.Slot_Of (Handle);
   begin
      Into := [others => ASCII.NUL];
      Last := Into'First - 1;

      if Position = 0
        or else Position > Natural (Self.Handles.Length)
        or else not Self.Handles (Position).Active
      then
         Result := Sed.IO.Failure (Sed.IO.Already_Closed);
         return;
      end if;

      declare
         Slot : Handle_Record := Self.Handles (Position);
         Item : constant Entry_Record := Self.Entries (Slot.Entry_Index);
         Available : constant Natural := U.Length (Item.Content) - Slot.Cursor;
      begin
         if Item.Read_Fails then
            Result :=
              Sed.IO.Failure (Sed.IO.IO_Failure, "injected read failure");
            return;
         end if;

         if Available = 0 then
            Result :=
              (Status => Sed.IO.End_Of_Data, Detail => U.Null_Unbounded_String);
            return;
         end if;

         declare
            Count : constant Natural := Natural'Min (Available, Into'Length);
         begin
            Into (Into'First .. Into'First + Count - 1) :=
              U.Slice (Item.Content, Slot.Cursor + 1, Slot.Cursor + Count);
            Last := Into'First + Count - 1;
            Slot.Cursor := Slot.Cursor + Count;
            Self.Handles.Replace_Element (Position, Slot);
         end;
      end;

      Result := Sed.IO.Success_Result;
   end Read;

   -----------------
   -- Close_Input --
   -----------------

   overriding procedure Close_Input
     (Self : in out Memory_Filesystem;
      Handle : in out Sed.IO.File_Handle)
   is
      Position : constant Natural := Sed.IO.Slot_Of (Handle);
   begin
      if Position /= 0 and then Position <= Natural (Self.Handles.Length) then
         declare
            Slot : Handle_Record := Self.Handles (Position);
         begin
            Slot.Active := False;
            Self.Handles.Replace_Element (Position, Slot);
         end;
      end if;

      Handle := Sed.IO.Invalid_Handle;
   end Close_Input;

   ---------------------
   -- Read_Whole_File --
   ---------------------

   overriding procedure Read_Whole_File
     (Self : in out Memory_Filesystem;
      Path : String;
      Content : out U.Unbounded_String;
      Result : out Sed.IO.IO_Result)
   is
      Index : constant Natural := Index_Of (Self, Path);
   begin
      Content := U.Null_Unbounded_String;

      if Index = 0 or else not Self.Entries (Index).Exists then
         Result := Sed.IO.Failure (Sed.IO.Not_Found);
         return;
      end if;

      if Self.Entries (Index).Open_Fails then
         Result := Sed.IO.Failure (Self.Entries (Index).Open_Status);
         return;
      end if;

      if Self.Entries (Index).Read_Fails then
         Result := Sed.IO.Failure (Sed.IO.IO_Failure, "injected read failure");
         return;
      end if;

      Content := Self.Entries (Index).Content;
      Result := Sed.IO.Success_Result;
   end Read_Whole_File;

   -------------------
   -- Create_Output --
   -------------------

   overriding procedure Create_Output
     (Self : in out Memory_Filesystem;
      Path : String;
      Handle : out Sed.IO.File_Handle;
      Result : out Sed.IO.IO_Result)
   is
      Index : Positive;
   begin
      Handle := Sed.IO.Invalid_Handle;
      Ensure_Entry (Self, Path, Index);

      if Self.Entries (Index).Create_Fails then
         Result := Sed.IO.Failure (Sed.IO.Permission_Denied);
         return;
      end if;

      declare
         Item : Entry_Record := Self.Entries (Index);
      begin
         --  Creating truncates, and the count lets a test prove that a
         --  destination named by several commands is truncated only once.
         Item.Content := U.Null_Unbounded_String;
         Item.Exists := True;
         Item.Creates := Item.Creates + 1;
         Self.Entries.Replace_Element (Index, Item);
      end;

      Claim_Handle
        (Self,
         Handle_Record'
           (Active => True, Writing => True, Entry_Index => Index, Cursor => 0),
         Handle);

      Result := Sed.IO.Success_Result;
   end Create_Output;

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self : in out Memory_Filesystem;
      Handle : Sed.IO.File_Handle;
      Data : String;
      Result : out Sed.IO.IO_Result)
   is
      Position : constant Natural := Sed.IO.Slot_Of (Handle);
   begin
      if Position = 0
        or else Position > Natural (Self.Handles.Length)
        or else not Self.Handles (Position).Active
      then
         Result := Sed.IO.Failure (Sed.IO.Already_Closed);
         return;
      end if;

      declare
         Slot : constant Handle_Record := Self.Handles (Position);
         Item : Entry_Record := Self.Entries (Slot.Entry_Index);
      begin
         if Item.Write_Fails then
            Result :=
              Sed.IO.Failure (Sed.IO.IO_Failure, "injected write failure");
            return;
         end if;

         U.Append (Item.Content, Data);
         Self.Entries.Replace_Element (Slot.Entry_Index, Item);
      end;

      Result := Sed.IO.Success_Result;
   end Write;

   ------------------
   -- Close_Output --
   ------------------

   overriding procedure Close_Output
     (Self : in out Memory_Filesystem;
      Handle : in out Sed.IO.File_Handle;
      Result : out Sed.IO.IO_Result)
   is
      Position : constant Natural := Sed.IO.Slot_Of (Handle);
   begin
      Result := Sed.IO.Success_Result;

      if Position = 0
        or else Position > Natural (Self.Handles.Length)
        or else not Self.Handles (Position).Active
      then
         Handle := Sed.IO.Invalid_Handle;
         Result := Sed.IO.Failure (Sed.IO.Already_Closed);
         return;
      end if;

      declare
         Slot : Handle_Record := Self.Handles (Position);
      begin
         Slot.Active := False;
         Self.Handles.Replace_Element (Position, Slot);
      end;

      Handle := Sed.IO.Invalid_Handle;
   end Close_Output;

end Sed_Test_Suite.Doubles;

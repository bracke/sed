with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Unchecked_Deallocation;

package body Sed.IO.Filesystem is

   use Ada.Streams;
   use type Ada.Directories.File_Kind;

   package Stream_IO renames Ada.Streams.Stream_IO;

   --  Transfer size for bulk reads. Large enough that whole-file reads do not
   --  churn, small enough that a single record never forces a large stack
   --  frame; the buffer lives on the heap-free stack of one call.
   Chunk_Size : constant := 64 * 1024;

   procedure Free is new Ada.Unchecked_Deallocation
     (Ada.Streams.Stream_IO.File_Type, Stream_File_Access);

   --  Classify a path before opening it, so that the common failures produce
   --  precise statuses instead of a single opaque one.
   function Classify (Path : String) return IO_Status;

   --  Convert a raw byte block to the String view used throughout the program.
   function To_String (Data : Stream_Element_Array) return String;

   --  Convert a String view back to raw bytes for writing.
   function To_Elements (Data : String) return Stream_Element_Array;

   --  Reserve a slot for a newly opened file and return its handle.
   procedure Claim_Slot
     (Self : in out Host_Filesystem;
      File : Stream_File_Access;
      Handle : out File_Handle);

   --------------
   -- Classify --
   --------------

   function Classify (Path : String) return IO_Status is
   begin
      if Path'Length = 0 then
         return Not_Found;
      end if;

      if not Ada.Directories.Exists (Path) then
         return Not_Found;
      end if;

      if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
         return Is_A_Directory;
      end if;

      --  Ordinary files and special files such as FIFOs and devices are both
      --  legitimate sed operands.
      return IO_Success;

   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         --  A path the host refuses to describe is reported as missing rather
         --  than as an internal fault.
         return Not_Found;
   end Classify;

   ---------------
   -- To_String --
   ---------------

   function To_String (Data : Stream_Element_Array) return String is
      Result : String (1 .. Data'Length);
      Target : Positive := 1;
   begin
      for Item of Data loop
         Result (Target) := Character'Val (Item);
         Target := Target + 1;
      end loop;

      return Result;
   end To_String;

   -----------------
   -- To_Elements --
   -----------------

   function To_Elements (Data : String) return Stream_Element_Array is
      Result : Stream_Element_Array (1 .. Stream_Element_Offset (Data'Length));
      Target : Stream_Element_Offset := 1;
   begin
      for Item of Data loop
         Result (Target) := Stream_Element (Character'Pos (Item));
         Target := Target + 1;
      end loop;

      return Result;
   end To_Elements;

   ----------------
   -- Claim_Slot --
   ----------------

   procedure Claim_Slot
     (Self : in out Host_Filesystem;
      File : Stream_File_Access;
      Handle : out File_Handle) is
   begin
      for Index in 1 .. Natural (Self.Slots.Length) loop
         if Self.Slots (Index) = null then
            Self.Slots (Index) := File;
            Handle := File_Handle (Index);
            return;
         end if;
      end loop;

      Self.Slots.Append (File);
      Handle := File_Handle (Self.Slots.Length);
   end Claim_Slot;

   ----------------
   -- Open_Input --
   ----------------

   overriding procedure Open_Input
     (Self : in out Host_Filesystem;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result)
   is
      Status : constant IO_Status := Classify (Path);
      File : Stream_File_Access;
   begin
      Handle := Invalid_Handle;

      if Status /= IO_Success then
         Result := Failure (Status);
         return;
      end if;

      File := new Stream_IO.File_Type;

      begin
         Stream_IO.Open (File.all, Stream_IO.In_File, Path);
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Free (File);
            Result := Failure (Not_Found);
            return;

         when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Status_Error =>
            Free (File);
            Result := Failure (Permission_Denied);
            return;

         when Ada.IO_Exceptions.Device_Error =>
            Free (File);
            Result := Failure (IO_Failure);
            return;
      end;

      Claim_Slot (Self, File, Handle);
      Result := Success_Result;
   end Open_Input;

   ----------
   -- Read --
   ----------

   overriding procedure Read
     (Self : in out Host_Filesystem;
      Handle : File_Handle;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      Into := [others => ASCII.NUL];
      Last := Into'First - 1;

      if Index = 0
        or else Index > Natural (Self.Slots.Length)
        or else Self.Slots (Index) = null
      then
         Result := Failure (Already_Closed);
         return;
      end if;

      declare
         File : Stream_IO.File_Type renames Self.Slots (Index).all;
         Block : Stream_Element_Array
           (1 .. Stream_Element_Offset (Into'Length));
         Final : Stream_Element_Offset;
      begin
         Stream_IO.Read (File, Block, Final);

         if Final < Block'First then
            Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);
            return;
         end if;

         declare
            Bytes : constant String := To_String (Block (Block'First .. Final));
         begin
            Into (Into'First .. Into'First + Bytes'Length - 1) := Bytes;
            Last := Into'First + Bytes'Length - 1;
         end;

         Result := Success_Result;

      exception
         when Ada.IO_Exceptions.End_Error =>
            Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);

         when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Data_Error =>
            Result := Failure (IO_Failure);

         when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
            Result := Failure (Already_Closed);
      end;
   end Read;

   -----------------
   -- Close_Input --
   -----------------

   overriding procedure Close_Input
     (Self : in out Host_Filesystem;
      Handle : in out File_Handle)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      if Index /= 0
        and then Index <= Natural (Self.Slots.Length)
        and then Self.Slots (Index) /= null
      then
         declare
            File : Stream_File_Access := Self.Slots (Index);
         begin
            begin
               if Stream_IO.Is_Open (File.all) then
                  Stream_IO.Close (File.all);
               end if;
            exception
               when others =>
                  --  Releasing a read handle cannot lose data, so a close
                  --  fault here has no observable effect to report.
                  null;
            end;

            Free (File);
            Self.Slots (Index) := null;
         end;
      end if;

      Handle := Invalid_Handle;
   end Close_Input;

   ---------------------
   -- Read_Whole_File --
   ---------------------

   overriding procedure Read_Whole_File
     (Self : in out Host_Filesystem;
      Path : String;
      Content : out U.Unbounded_String;
      Result : out IO_Result)
   is
      Handle : File_Handle;
      Buffer : String (1 .. Chunk_Size);
      Last : Natural;
      Step : IO_Result;
   begin
      Content := U.Null_Unbounded_String;
      Open_Input (Self, Path, Handle, Result);

      if Is_Failure (Result) then
         return;
      end if;

      loop
         Read (Self, Handle, Buffer, Last, Step);

         exit when Step.Status = End_Of_Data;

         if Is_Failure (Step) then
            Close_Input (Self, Handle);
            Content := U.Null_Unbounded_String;
            Result := Step;
            return;
         end if;

         if Last >= Buffer'First then
            U.Append (Content, Buffer (Buffer'First .. Last));
         end if;
      end loop;

      Close_Input (Self, Handle);
      Result := Success_Result;
   end Read_Whole_File;

   -------------------
   -- Create_Output --
   -------------------

   overriding procedure Create_Output
     (Self : in out Host_Filesystem;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result)
   is
      File : Stream_File_Access;
   begin
      Handle := Invalid_Handle;

      if Path'Length = 0 then
         Result := Failure (Not_Found);
         return;
      end if;

      if Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Directory
      then
         Result := Failure (Is_A_Directory);
         return;
      end if;

      File := new Stream_IO.File_Type;

      begin
         Stream_IO.Create (File.all, Stream_IO.Out_File, Path);
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Free (File);
            Result := Failure (Not_Found);
            return;

         when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Status_Error =>
            Free (File);
            Result := Failure (Permission_Denied);
            return;

         when Ada.IO_Exceptions.Device_Error =>
            Free (File);
            Result := Failure (IO_Failure);
            return;
      end;

      Claim_Slot (Self, File, Handle);
      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error =>
         Result := Failure (Permission_Denied);
   end Create_Output;

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self : in out Host_Filesystem;
      Handle : File_Handle;
      Data : String;
      Result : out IO_Result)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      if Index = 0
        or else Index > Natural (Self.Slots.Length)
        or else Self.Slots (Index) = null
      then
         Result := Failure (Already_Closed);
         return;
      end if;

      if Data'Length = 0 then
         Result := Success_Result;
         return;
      end if;

      begin
         Stream_IO.Write (Self.Slots (Index).all, To_Elements (Data));
         Result := Success_Result;
      exception
         when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
            Result := Failure (IO_Failure);

         when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
            Result := Failure (Already_Closed);
      end;
   end Write;

   ------------------
   -- Close_Output --
   ------------------

   overriding procedure Close_Output
     (Self : in out Host_Filesystem;
      Handle : in out File_Handle;
      Result : out IO_Result)
   is
      Index : constant Natural := Slot_Of (Handle);
   begin
      Result := Success_Result;

      if Index = 0
        or else Index > Natural (Self.Slots.Length)
        or else Self.Slots (Index) = null
      then
         Handle := Invalid_Handle;
         Result := Failure (Already_Closed);
         return;
      end if;

      declare
         File : Stream_File_Access := Self.Slots (Index);
      begin
         begin
            if Stream_IO.Is_Open (File.all) then
               Stream_IO.Close (File.all);
            end if;
         exception
            when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
               --  A close fault on an output file can mean buffered data was
               --  never written, so it must reach the caller.
               Result := Failure (IO_Failure);

            when others =>
               Result := Failure (IO_Failure);
         end;

         Free (File);
         Self.Slots (Index) := null;
      end;

      Handle := Invalid_Handle;
   end Close_Output;

   ----------------
   -- Open_Count --
   ----------------

   function Open_Count (Self : Host_Filesystem) return Natural is
      Count : Natural := 0;
   begin
      for Slot of Self.Slots loop
         if Slot /= null then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Open_Count;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Host_Filesystem) is
   begin
      for Index in 1 .. Natural (Self.Slots.Length) loop
         if Self.Slots (Index) /= null then
            declare
               File : Stream_File_Access := Self.Slots (Index);
            begin
               begin
                  if Stream_IO.Is_Open (File.all) then
                     Stream_IO.Close (File.all);
                  end if;
               exception
                  when others =>
                     null;
               end;

               Free (File);
               Self.Slots (Index) := null;
            end;
         end if;
      end loop;
   end Finalize;

end Sed.IO.Filesystem;

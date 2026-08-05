with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Text_IO.Text_Streams;
with Interfaces.C_Streams;

package body Sed.IO.Process_Streams is

   use Ada.Streams;

   --  Convert a String view to raw bytes for writing.
   function To_Elements (Data : String) return Stream_Element_Array;

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

   ---------------------------
   -- Descriptor_Is_Terminal --
   ---------------------------

   function Descriptor_Is_Terminal (Descriptor : Natural) return Boolean is
   begin
      return Interfaces.C_Streams.isatty
        (Interfaces.C_Streams.int (Descriptor)) = 1;
   exception
      when others =>
         --  A host that cannot answer the question is treated as not a
         --  terminal, which is the choice that never emits escape sequences
         --  into a file.
         return False;
   end Descriptor_Is_Terminal;

   -----------
   -- Write --
   -----------

   overriding procedure Write
     (Self : in out Process_Output;
      Data : String;
      Result : out IO_Result) is
   begin
      if Data'Length = 0 then
         Result := Success_Result;
         return;
      end if;

      case Self.Channel is
         when Output_Channel =>
            Ada.Streams.Write
              (Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Output).all,
               To_Elements (Data));

         when Error_Channel =>
            Ada.Streams.Write
              (Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Error).all,
               To_Elements (Data));
      end case;

      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
         --  A closed pipe or a full device reaches the caller as a structured
         --  failure; it never escapes as an unhandled exception with a
         --  traceback.
         Result := Failure (IO_Failure);

      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
         Result := Failure (Already_Closed);
   end Write;

   -----------
   -- Flush --
   -----------

   overriding procedure Flush
     (Self : in out Process_Output;
      Result : out IO_Result) is
   begin
      case Self.Channel is
         when Output_Channel =>
            Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);

         when Error_Channel =>
            Ada.Text_IO.Flush (Ada.Text_IO.Standard_Error);
      end case;

      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Use_Error =>
         Result := Failure (IO_Failure);

      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
         Result := Failure (Already_Closed);
   end Flush;

   -----------------
   -- Is_Terminal --
   -----------------

   overriding function Is_Terminal (Self : Process_Output) return Boolean is
   begin
      return Descriptor_Is_Terminal
        ((case Self.Channel is
            when Output_Channel => 1,
            when Error_Channel  => 2));
   end Is_Terminal;

   ----------
   -- Read --
   ----------

   overriding procedure Read
     (Self : in out Process_Input;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result)
   is
      Block : Stream_Element_Array (1 .. Stream_Element_Offset (Into'Length));
      Final : Stream_Element_Offset;
   begin
      Into := [others => ASCII.NUL];
      Last := Into'First - 1;

      if Self.Exhausted then
         --  Standard input is a single stream: a second "-" operand observes
         --  end of file rather than rewinding.
         Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);
         return;
      end if;

      Ada.Streams.Read
        (Ada.Text_IO.Text_Streams.Stream (Ada.Text_IO.Standard_Input).all,
         Block,
         Final);

      if Final < Block'First then
         Self.Exhausted := True;
         Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);
         return;
      end if;

      for Offset in Block'First .. Final loop
         Into (Into'First + Natural (Offset - Block'First)) :=
           Character'Val (Block (Offset));
      end loop;

      Last := Into'First + Natural (Final - Block'First);
      Result := Success_Result;

   exception
      when Ada.IO_Exceptions.End_Error =>
         Self.Exhausted := True;
         Result := (Status => End_Of_Data, Detail => U.Null_Unbounded_String);

      when Ada.IO_Exceptions.Device_Error | Ada.IO_Exceptions.Data_Error =>
         Result := Failure (IO_Failure);

      when Ada.IO_Exceptions.Status_Error | Ada.IO_Exceptions.Mode_Error =>
         Result := Failure (Already_Closed);
   end Read;

end Sed.IO.Process_Streams;

package body Sed.Output.Standard is

   package D renames Sed.Diagnostics;

   --  Record the first failure and ignore every later one.
   procedure Note_Failure (Self : in out Writer; Result : Sed.IO.IO_Result);

   ------------------
   -- Note_Failure --
   ------------------

   procedure Note_Failure (Self : in out Writer; Result : Sed.IO.IO_Result) is
   begin
      if Self.Broken then
         return;
      end if;

      Self.Broken := True;
      Self.Diagnostic := D.Make (D.Standard_Output_Failed);

      if Sed.IO.U.Length (Result.Detail) > 0 then
         D.Set (Self.Diagnostic, D.Detail, Sed.IO.U.To_String (Result.Detail));
      end if;
   end Note_Failure;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : in out Writer;
      Sink : not null access Sed.IO.Output_Stream_Interface'Class) is
   begin
      Self.Sink := Sink;
      Self.Broken := False;
      Self.Pending_Separator := False;
      Self.Written := 0;
      Self.Diagnostic := D.Make (D.Standard_Output_Failed);
   end Initialize;

   -----------
   -- Write --
   -----------

   procedure Write
     (Self : in out Writer;
      Data : String;
      Terminator : Terminator_Policy)
   is
      Result : Sed.IO.IO_Result;
   begin
      if Self.Broken or else Self.Sink = null then
         return;
      end if;

      --  An unterminated write can only legitimately be the last thing the
      --  program emits: a final input line without a newline is copied back
      --  without one. If anything follows it, the separator it was missing is
      --  supplied now, so lines never run together and the stream still ends
      --  exactly as the input did.
      if Self.Pending_Separator then
         Self.Sink.Write ([1 => ASCII.LF], Result);

         if Sed.IO.Is_Failure (Result) then
            Note_Failure (Self, Result);
            return;
         end if;

         Self.Written := Self.Written + 1;
         Self.Pending_Separator := False;
      end if;

      if Data'Length > 0 then
         Self.Sink.Write (Data, Result);

         if Sed.IO.Is_Failure (Result) then
            Note_Failure (Self, Result);
            return;
         end if;

         Self.Written := Self.Written + Line_Count (Data'Length);
      end if;

      if Terminator = With_Terminator then
         Self.Sink.Write ([1 => ASCII.LF], Result);

         if Sed.IO.Is_Failure (Result) then
            Note_Failure (Self, Result);
            return;
         end if;

         Self.Written := Self.Written + 1;
      else
         Self.Pending_Separator := True;
      end if;
   end Write;

   -----------
   -- Flush --
   -----------

   procedure Flush (Self : in out Writer) is
      Result : Sed.IO.IO_Result;
   begin
      if Self.Broken or else Self.Sink = null then
         return;
      end if;

      Self.Sink.Flush (Result);

      if Sed.IO.Is_Failure (Result) then
         Note_Failure (Self, Result);
      end if;
   end Flush;

   ------------
   -- Failed --
   ------------

   function Failed (Self : Writer) return Boolean is
   begin
      return Self.Broken;
   end Failed;

   -------------------
   -- Bytes_Written --
   -------------------

   function Bytes_Written (Self : Writer) return Line_Count is
   begin
      return Self.Written;
   end Bytes_Written;

   -------------
   -- Failure --
   -------------

   function Failure (Self : Writer) return D.Diagnostic is
   begin
      return Self.Diagnostic;
   end Failure;

end Sed.Output.Standard;

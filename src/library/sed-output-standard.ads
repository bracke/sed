with Sed.Diagnostics;
with Sed.IO;

--  Standard output for sed program data.
--
--  During execution this stream carries nothing but the bytes the sed script
--  produces: automatic printing, p, P, =, l, a, i, c and r output. No
--  diagnostic, severity label, hint, progress note or escape sequence is ever
--  written here.
--
--  A write or flush failure is fatal, and only the first one is reported: a
--  closed pipe would otherwise produce one diagnostic per remaining line.
package Sed.Output.Standard is

   type Writer is limited private;

   --  @param Self Writer to prepare.
   --  @param Sink Byte sink to write through.
   procedure Initialize
     (Self : in out Writer;
      Sink : not null access Sed.IO.Output_Stream_Interface'Class)
     with Post => not Failed (Self);

   --  Write bytes, optionally followed by a newline.
   --
   --  @param Self Writer to use.
   --  @param Data Bytes to write, possibly empty.
   --  @param Terminator Whether to append a newline.
   procedure Write
     (Self : in out Writer;
      Data : String;
      Terminator : Terminator_Policy);

   --  Push buffered bytes towards the operating system.
   --
   --  @param Self Writer to flush.
   procedure Flush (Self : in out Writer);

   --  @param Self Writer to inspect.
   --  @return True when a write or flush has failed.
   function Failed (Self : Writer) return Boolean;

   --  @param Self Writer to inspect.
   --  @return Number of bytes handed to the sink.
   function Bytes_Written (Self : Writer) return Line_Count;

   --  The single diagnostic describing the first failure.
   --
   --  @param Self Writer to inspect.
   --  @return Structured failure diagnostic.
   function Failure (Self : Writer) return Sed.Diagnostics.Diagnostic
     with Pre => Failed (Self);

private

   type Writer is limited record
      Sink : access Sed.IO.Output_Stream_Interface'Class := null;
      Broken : Boolean := False;
      --  Set when the last write carried no terminator, so that a following
      --  write supplies the separator it omitted.
      Pending_Separator : Boolean := False;
      Written : Line_Count := 0;
      Diagnostic : Sed.Diagnostics.Diagnostic :=
        Sed.Diagnostics.Make (Sed.Diagnostics.Standard_Output_Failed);
   end record;

end Sed.Output.Standard;

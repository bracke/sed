private with Ada.Containers.Vectors;
private with Sed.Input.Cursor;
private with Sed.Input.Delivery;
private with Ada.Finalization;
with Sed.Diagnostics;
with Sed.IO;

--  The single logical input stream formed by every input operand.
--
--  Operands are opened lazily and in order, so an early q does not open files
--  the script never reads, and a blocking special file is not touched until
--  the stream actually needs it.
--
--  File boundaries are invisible to sed semantics: global line numbers
--  continue across operands, an empty operand contributes no line at all, and
--  the final line of one operand is the final line of the stream only when no
--  later operand produces data. Determining that requires one line of
--  lookahead, which is why the last line of a file is delivered only once the
--  stream knows whether anything follows it.
--
--  Opening and reading failures are structured results. A named operand that
--  cannot be opened or read is reported and skipped so that later operands
--  still run; a standard-input failure ends the stream, because there is no
--  later position to recover to.
package Sed.Input.Logical_Stream is

   type Stream is limited private;

   --  Prepare a stream over the given operands.
   --
   --  With no operands the stream reads standard input, which is what POSIX
   --  requires of a bare invocation.
   --
   --  @param Self Stream to prepare.
   --  @param Files Filesystem used for named operands.
   --  @param Standard_In Byte source used for "-" operands.
   procedure Initialize
     (Self : in out Stream;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Standard_In : not null access Sed.IO.Input_Source_Interface'Class)
     with Post => Delivered_Count (Self) = 0;

   --  Append an input operand in command-line order.
   --
   --  @param Self Stream to extend.
   --  @param Item Operand to append.
   procedure Add_Operand (Self : in out Stream; Item : Operand)
     with Pre => Delivered_Count (Self) = 0;

   --  Produce the next logical line.
   --
   --  Status is Record_Available when Item holds a line, End_Of_Input when
   --  every operand is exhausted, and Read_Failed when the stream cannot
   --  continue at all. Recoverable operand failures do not stop the stream;
   --  they are reported through Take_Diagnostics and the stream moves on.
   --
   --  @param Self Stream to advance.
   --  @param Item Delivered line, meaningful when Status is Record_Available.
   --  @param Status Outcome of the attempt.
   procedure Next
     (Self : in out Stream;
      Item : out Input_Line;
      Status : out Record_Status);

   --  Remove and return the diagnostics accumulated so far.
   --
   --  The stream reports failures as data rather than writing them anywhere,
   --  so the application decides when and how they are rendered.
   --
   --  @param Self Stream to drain.
   --  @param Into Diagnostics collected since the previous call.
   procedure Take_Diagnostics
     (Self : in out Stream;
      Into : out Sed.Diagnostics.Diagnostic_List);

   --  @param Self Stream to inspect.
   --  @return Number of lines delivered so far.
   function Delivered_Count (Self : Stream) return Line_Number;

   --  @param Self Stream to inspect.
   --  @return True when a line has been delivered that was marked final.
   function Final_Line_Delivered (Self : Stream) return Boolean;

   --  Release every operand the stream still holds open.
   --
   --  @param Self Stream to close.
   procedure Close (Self : in out Stream);

private

   package Operand_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Operand);

   type Stream is limited new Ada.Finalization.Limited_Controlled with record
      Files : access Sed.IO.Filesystem_Interface'Class := null;
      Standard_In : access Sed.IO.Input_Source_Interface'Class := null;

      Operands : Operand_Vectors.Vector := Operand_Vectors.Empty_Vector;

      --  Which operand is being read, and whether it has been opened. The
      --  contracts on Sed.Input.Cursor are what keep the walk ordered, open
      --  each operand at most once, and guarantee it ends.
      Cursor : Sed.Input.Cursor.Position := Sed.Input.Cursor.Starting (0);
      Handle : Sed.IO.File_Handle := Sed.IO.Invalid_Handle;

      --  Bytes read from the current operand but not yet split into lines.
      Buffer : U.Unbounded_String := U.Null_Unbounded_String;
      --  True once the current operand has reported end of data.
      Source_Drained : Boolean := False;

      --  Line counters. The global count, the delivered count and the
      --  final-line flag live together in Sed.Input.Delivery, whose contracts
      --  are what rule out a repeated line number or a second final line.
      Counters : Sed.Input.Delivery.Counters := Sed.Input.Delivery.Start;
      Local : Line_Number := 0;

      --  One line of lookahead, needed to decide which line is final.
      Have_Pending : Boolean := False;
      Pending : Input_Line;

      --  Set when standard input fails, which the stream cannot recover from.
      Fatal : Boolean := False;

      Diagnostics : Sed.Diagnostics.Diagnostic_List :=
        Sed.Diagnostics.Empty_List;
   end record;

   overriding procedure Finalize (Self : in out Stream);

end Sed.Input.Logical_Stream;

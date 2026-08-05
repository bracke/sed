with Ada.Strings.Unbounded;

--  Byte-exact I/O abstractions.
--
--  Every stream in this program carries octets, not text. String is used as
--  the byte vector because Character is one octet on the supported platforms;
--  nothing here converts encodings, translates line endings or interprets the
--  data in any way. That is what makes sed data survive unchanged from input
--  operand to standard output.
--
--  All operations report structured results. Opening a missing file, reading
--  past the end of a file and failing to write are ordinary outcomes, not
--  exceptions, so no caller has to use exception handling for control flow.
--
--  Implementations live in Sed.IO.Filesystem and Sed.IO.Process_Streams;
--  tests substitute their own, which is how deterministic failure injection
--  works without depending on host filesystem permissions.
package Sed.IO is

   package U renames Ada.Strings.Unbounded;

   type IO_Status is
     (IO_Success,
      End_Of_Data,
      Not_Found,
      Permission_Denied,
      Is_A_Directory,
      Already_Closed,
      IO_Failure);

   subtype Failure_Status is IO_Status range Not_Found .. IO_Failure;

   type IO_Result is record
      Status : IO_Status := IO_Success;
      --  Optional technical annotation for diagnostics. Never user-facing on
      --  its own: it is escaped and rendered as a detail parameter.
      Detail : U.Unbounded_String := U.Null_Unbounded_String;
   end record;

   Success_Result : constant IO_Result :=
     (Status => IO_Success, Detail => U.Null_Unbounded_String);

   --  @param Status Status to classify.
   --  @return True when the status denotes a failure rather than progress.
   function Is_Failure (Status : IO_Status) return Boolean
     is (Status in Failure_Status);

   --  @param Result Result to classify.
   --  @return True when the result denotes a failure.
   function Is_Failure (Result : IO_Result) return Boolean
     is (Is_Failure (Result.Status));

   --  @param Status Failure status.
   --  @param Detail Optional technical annotation.
   --  @return Structured failure result.
   function Failure
     (Status : Failure_Status;
      Detail : String := "") return IO_Result
     is ((Status => Status, Detail => U.To_Unbounded_String (Detail)));

   --  A sequential byte sink such as standard output or standard error.
   type Output_Stream_Interface is limited interface;

   --  Write every byte of Data.
   --
   --  @param Self Stream to write to.
   --  @param Data Bytes to write, possibly empty.
   --  @param Result Structured outcome.
   procedure Write
     (Self : in out Output_Stream_Interface;
      Data : String;
      Result : out IO_Result) is abstract;

   --  Push buffered bytes towards the operating system.
   --
   --  @param Self Stream to flush.
   --  @param Result Structured outcome.
   procedure Flush
     (Self : in out Output_Stream_Interface;
      Result : out IO_Result) is abstract;

   --  @param Self Stream to inspect.
   --  @return True when the destination is a terminal.
   function Is_Terminal (Self : Output_Stream_Interface) return Boolean is abstract;

   --  A sequential byte source such as standard input.
   type Input_Source_Interface is limited interface;

   --  Read at most Into'Length bytes.
   --
   --  Last is Into'First - 1 when no byte was produced. A result status of
   --  End_Of_Data means the source is exhausted; a short read with
   --  IO_Success is normal and does not mean end of data.
   --
   --  @param Self Stream to read from.
   --  @param Into Destination buffer.
   --  @param Last Index of the final byte written into Into.
   --  @param Result Structured outcome.
   procedure Read
     (Self : in out Input_Source_Interface;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result) is abstract;

   --  Opaque token for an open file owned by a Filesystem.
   --
   --  Handles are values rather than access types, so ownership stays with
   --  the filesystem object, a test double can implement the interface with
   --  no allocation at all, and no caller can leak or double-free a stream.
   type File_Handle is private;

   Invalid_Handle : constant File_Handle;

   --  @param Handle Handle to test.
   --  @return True when the handle refers to an open file.
   function Is_Open (Handle : File_Handle) return Boolean;

   --  Mint a handle for a slot an implementation owns.
   --
   --  Only an implementation of Filesystem_Interface calls this: the handle
   --  is an opaque token to everyone else, and the slot number means whatever
   --  the implementation that issued it decides.
   --
   --  @param Slot Implementation-chosen slot number.
   --  @return Handle referring to that slot.
   function To_Handle (Slot : Positive) return File_Handle
     with Post => Is_Open (To_Handle'Result);

   --  Recover the slot an implementation encoded in a handle.
   --
   --  @param Handle Handle issued by this implementation.
   --  @return Slot number, or zero for a closed handle.
   function Slot_Of (Handle : File_Handle) return Natural
     with Post => (Slot_Of'Result = 0) = not Is_Open (Handle);

   --  Filesystem access used by script loading, input operands, w
   --  destinations and the r command.
   --
   --  The program never invokes a shell and never passes a path through one:
   --  paths reach the host exactly as the user wrote them.
   type Filesystem_Interface is limited interface;

   --  Open an existing file for reading.
   --
   --  @param Self Filesystem to use.
   --  @param Path Raw path as supplied by the user.
   --  @param Handle Resulting handle; Invalid_Handle on failure.
   --  @param Result Structured outcome.
   procedure Open_Input
     (Self : in out Filesystem_Interface;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result) is abstract
     with Post'Class => Is_Open (Handle) = not Is_Failure (Result);

   --  Read the next bytes of an open input file.
   --
   --  @param Self Filesystem to use.
   --  @param Handle Handle from Open_Input.
   --  @param Into Destination buffer.
   --  @param Last Index of the final byte written into Into.
   --  @param Result Structured outcome.
   procedure Read
     (Self : in out Filesystem_Interface;
      Handle : File_Handle;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result) is abstract;

   --  Release an input handle. Closing is idempotent.
   --
   --  @param Self Filesystem to use.
   --  @param Handle Handle to release.
   procedure Close_Input
     (Self : in out Filesystem_Interface;
      Handle : in out File_Handle) is abstract
     with Post'Class => not Is_Open (Handle);

   --  Read a whole file into memory.
   --
   --  Used for -f script files and for the r command, both of which are
   --  defined in terms of complete file contents.
   --
   --  @param Self Filesystem to use.
   --  @param Path Raw path as supplied by the user.
   --  @param Content Complete file contents on success.
   --  @param Result Structured outcome.
   procedure Read_Whole_File
     (Self : in out Filesystem_Interface;
      Path : String;
      Content : out U.Unbounded_String;
      Result : out IO_Result) is abstract;

   --  Create or truncate a file for writing.
   --
   --  @param Self Filesystem to use.
   --  @param Path Raw path as supplied by the user.
   --  @param Handle Resulting handle; Invalid_Handle on failure.
   --  @param Result Structured outcome.
   procedure Create_Output
     (Self : in out Filesystem_Interface;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result) is abstract
     with Post'Class => Is_Open (Handle) = not Is_Failure (Result);

   --  Append bytes to an open output file.
   --
   --  @param Self Filesystem to use.
   --  @param Handle Handle from Create_Output.
   --  @param Data Bytes to write, possibly empty.
   --  @param Result Structured outcome.
   procedure Write
     (Self : in out Filesystem_Interface;
      Handle : File_Handle;
      Data : String;
      Result : out IO_Result) is abstract;

   --  Flush and release an output handle.
   --
   --  Closing reports failures because a deferred write error must not be
   --  swallowed by finalization.
   --
   --  @param Self Filesystem to use.
   --  @param Handle Handle to release.
   --  @param Result Structured outcome.
   procedure Close_Output
     (Self : in out Filesystem_Interface;
      Handle : in out File_Handle;
      Result : out IO_Result) is abstract
     with Post'Class => not Is_Open (Handle);

private

   type File_Handle is new Natural;

   Invalid_Handle : constant File_Handle := 0;

   function Is_Open (Handle : File_Handle) return Boolean
     is (Handle /= Invalid_Handle);

   function To_Handle (Slot : Positive) return File_Handle
     is (File_Handle (Slot));

   function Slot_Of (Handle : File_Handle) return Natural
     is (Natural (Handle));

end Sed.IO;

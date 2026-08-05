private with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Sed.IO;

--  In-memory substitutes for the process environment.
--
--  Every test drives the real application through the same seam production
--  uses; only what is injected differs. Because these doubles are ordinary
--  data structures, failure injection is exact and repeatable: a test says
--  "this open fails", "this read fails after 12 bytes", "this write fails",
--  and gets that behaviour on every host, with no reliance on filesystem
--  permissions, full disks or unwritable directories.
package Sed_Test_Suite.Doubles is

   package U renames Ada.Strings.Unbounded;

   --  Byte sink that records everything written to it.
   type Memory_Output is limited new Sed.IO.Output_Stream_Interface with private;

   overriding procedure Write
     (Self : in out Memory_Output;
      Data : String;
      Result : out Sed.IO.IO_Result);

   overriding procedure Flush
     (Self : in out Memory_Output;
      Result : out Sed.IO.IO_Result);

   overriding function Is_Terminal (Self : Memory_Output) return Boolean;

   --  @param Self Sink to inspect.
   --  @return Every byte written so far.
   function Text (Self : Memory_Output) return String;

   --  @param Self Sink to inspect.
   --  @return Number of Flush calls that succeeded.
   function Flush_Count (Self : Memory_Output) return Natural;

   --  Present the sink as a terminal, so styling policy can be exercised.
   --
   --  @param Self Sink to configure.
   --  @param Value True to report a terminal.
   procedure Set_Terminal (Self : in out Memory_Output; Value : Boolean);

   --  Fail every write once this many bytes have been accepted.
   --
   --  @param Self Sink to configure.
   --  @param After_Bytes Byte threshold after which writes fail.
   procedure Fail_Writes_After
     (Self : in out Memory_Output; After_Bytes : Natural);

   --  Make Flush fail.
   --
   --  @param Self Sink to configure.
   procedure Fail_Flush (Self : in out Memory_Output);

   --  Byte source serving a fixed text.
   type Memory_Input is limited new Sed.IO.Input_Source_Interface with private;

   --  @param Self Source to fill.
   --  @param Data Bytes the source will deliver.
   procedure Set_Text (Self : in out Memory_Input; Data : String);

   --  Fail the read that would start at or after this offset.
   --
   --  @param Self Source to configure.
   --  @param After_Bytes Byte threshold after which reads fail.
   procedure Fail_Reads_After
     (Self : in out Memory_Input; After_Bytes : Natural);

   overriding procedure Read
     (Self : in out Memory_Input;
      Into : out String;
      Last : out Natural;
      Result : out Sed.IO.IO_Result);

   --  Filesystem holding named byte blobs in memory.
   type Memory_Filesystem is
     limited new Sed.IO.Filesystem_Interface with private;

   --  Place a readable file into the filesystem.
   --
   --  @param Self Filesystem to populate.
   --  @param Path Path the file answers to.
   --  @param Content Exact bytes of the file.
   procedure Add_File
     (Self : in out Memory_Filesystem;
      Path : String;
      Content : String);

   --  @param Self Filesystem to inspect.
   --  @param Path Path to look up.
   --  @return True when a file with that path exists.
   function Exists (Self : Memory_Filesystem; Path : String) return Boolean;

   --  @param Self Filesystem to inspect.
   --  @param Path Path to read.
   --  @return Current contents, empty when the file does not exist.
   function Content (Self : Memory_Filesystem; Path : String) return String;

   --  Make opening this path for reading fail.
   --
   --  @param Self Filesystem to configure.
   --  @param Path Path that will fail to open.
   --  @param Status Failure to report.
   procedure Fail_Open
     (Self : in out Memory_Filesystem;
      Path : String;
      Status : Sed.IO.Failure_Status := Sed.IO.Permission_Denied);

   --  Make reading this path fail after it has been opened.
   --
   --  @param Self Filesystem to configure.
   --  @param Path Path whose reads will fail.
   procedure Fail_Read (Self : in out Memory_Filesystem; Path : String);

   --  Make creating this path for writing fail.
   --
   --  @param Self Filesystem to configure.
   --  @param Path Path that will fail to be created.
   procedure Fail_Create (Self : in out Memory_Filesystem; Path : String);

   --  Make writing to this path fail.
   --
   --  @param Self Filesystem to configure.
   --  @param Path Path whose writes will fail.
   procedure Fail_Write (Self : in out Memory_Filesystem; Path : String);

   --  @param Self Filesystem to inspect.
   --  @param Path Path to look up.
   --  @return How many times the path has been created or truncated.
   function Create_Count
     (Self : Memory_Filesystem; Path : String) return Natural;

   --  @param Self Filesystem to inspect.
   --  @return Number of handles still open.
   function Open_Count (Self : Memory_Filesystem) return Natural;

   overriding procedure Open_Input
     (Self : in out Memory_Filesystem;
      Path : String;
      Handle : out Sed.IO.File_Handle;
      Result : out Sed.IO.IO_Result);

   overriding procedure Read
     (Self : in out Memory_Filesystem;
      Handle : Sed.IO.File_Handle;
      Into : out String;
      Last : out Natural;
      Result : out Sed.IO.IO_Result);

   overriding procedure Close_Input
     (Self : in out Memory_Filesystem;
      Handle : in out Sed.IO.File_Handle);

   overriding procedure Read_Whole_File
     (Self : in out Memory_Filesystem;
      Path : String;
      Content : out U.Unbounded_String;
      Result : out Sed.IO.IO_Result);

   overriding procedure Create_Output
     (Self : in out Memory_Filesystem;
      Path : String;
      Handle : out Sed.IO.File_Handle;
      Result : out Sed.IO.IO_Result);

   overriding procedure Write
     (Self : in out Memory_Filesystem;
      Handle : Sed.IO.File_Handle;
      Data : String;
      Result : out Sed.IO.IO_Result);

   overriding procedure Close_Output
     (Self : in out Memory_Filesystem;
      Handle : in out Sed.IO.File_Handle;
      Result : out Sed.IO.IO_Result);

private

   type Memory_Output is limited new Sed.IO.Output_Stream_Interface with record
      Buffer : U.Unbounded_String := U.Null_Unbounded_String;
      Terminal : Boolean := False;
      Flushes : Natural := 0;
      Write_Limit : Natural := Natural'Last;
      Flush_Fails : Boolean := False;
   end record;

   type Memory_Input is limited new Sed.IO.Input_Source_Interface with record
      Buffer : U.Unbounded_String := U.Null_Unbounded_String;
      Cursor : Natural := 0;
      Read_Limit : Natural := Natural'Last;
   end record;

   type Entry_Record is record
      Path : U.Unbounded_String := U.Null_Unbounded_String;
      Content : U.Unbounded_String := U.Null_Unbounded_String;
      Exists : Boolean := False;
      Open_Fails : Boolean := False;
      Open_Status : Sed.IO.Failure_Status := Sed.IO.Permission_Denied;
      Read_Fails : Boolean := False;
      Create_Fails : Boolean := False;
      Write_Fails : Boolean := False;
      Creates : Natural := 0;
   end record;

   package Entry_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Entry_Record);

   type Handle_Record is record
      Active : Boolean := False;
      Writing : Boolean := False;
      Entry_Index : Natural := 0;
      Cursor : Natural := 0;
   end record;

   package Handle_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Handle_Record);

   type Memory_Filesystem is
     limited new Sed.IO.Filesystem_Interface with record
      Entries : Entry_Vectors.Vector := Entry_Vectors.Empty_Vector;
      Handles : Handle_Vectors.Vector := Handle_Vectors.Empty_Vector;
   end record;

end Sed_Test_Suite.Doubles;

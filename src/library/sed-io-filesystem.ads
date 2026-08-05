private with Ada.Containers.Vectors;
private with Ada.Finalization;
private with Ada.Streams.Stream_IO;

--  Real filesystem access built on Ada.Streams.Stream_IO.
--
--  Stream_IO is used rather than Text_IO because it moves octets without any
--  line-ending translation or encoding conversion, which is what byte-exact
--  sed behaviour requires.
--
--  The object owns every file it opens. Closing is explicit so that deferred
--  write errors can be reported; finalization closes anything still open as a
--  safety net rather than as the normal cleanup path.
package Sed.IO.Filesystem is

   type Host_Filesystem is limited new Sed.IO.Filesystem_Interface with private;

   overriding procedure Open_Input
     (Self : in out Host_Filesystem;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result);

   overriding procedure Read
     (Self : in out Host_Filesystem;
      Handle : File_Handle;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result);

   overriding procedure Close_Input
     (Self : in out Host_Filesystem;
      Handle : in out File_Handle);

   overriding procedure Read_Whole_File
     (Self : in out Host_Filesystem;
      Path : String;
      Content : out U.Unbounded_String;
      Result : out IO_Result);

   overriding procedure Create_Output
     (Self : in out Host_Filesystem;
      Path : String;
      Handle : out File_Handle;
      Result : out IO_Result);

   overriding procedure Write
     (Self : in out Host_Filesystem;
      Handle : File_Handle;
      Data : String;
      Result : out IO_Result);

   overriding procedure Close_Output
     (Self : in out Host_Filesystem;
      Handle : in out File_Handle;
      Result : out IO_Result);

   --  Number of files currently open through this object.
   --
   --  Tests assert that the count returns to zero, which is how resource
   --  leaks are caught without relying on host process inspection.
   --
   --  @param Self Filesystem to inspect.
   --  @return Count of open handles.
   function Open_Count (Self : Host_Filesystem) return Natural;

private

   type Stream_File_Access is access Ada.Streams.Stream_IO.File_Type;

   package Slot_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Stream_File_Access);

   type Host_Filesystem is
     limited new Ada.Finalization.Limited_Controlled and Sed.IO.Filesystem_Interface with
      record
         --  Index i holds the file for handle i, or null when that slot is
         --  free and available for reuse.
         Slots : Slot_Vectors.Vector := Slot_Vectors.Empty_Vector;
      end record;

   overriding procedure Finalize (Self : in out Host_Filesystem);

end Sed.IO.Filesystem;

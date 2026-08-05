private with Ada.Containers.Indefinite_Vectors;
private with Ada.Finalization;
with Sed.Diagnostics;
with Sed.IO;

--  Registry of the files a script writes to with w and s///w.
--
--  Every destination is created, and therefore truncated, exactly once. The
--  registry is populated from the compiled program before execution starts,
--  so a script that fails to compile never touches an existing file, and a
--  destination named by several commands is one shared, append-ordered file
--  rather than a file that is re-truncated on each reference.
--
--  Failures are reported honestly and without any claim of rollback: bytes
--  already written stay written.
package Sed.Output.Named_Files is

   type Registry is limited private;

   --  @param Self Registry to prepare.
   --  @param Files Filesystem that will own the destination handles.
   procedure Initialize
     (Self : in out Registry;
      Files : not null access Sed.IO.Filesystem_Interface'Class)
     with Post => Destination_Count (Self) = 0;

   --  Create or truncate a destination, once.
   --
   --  A second call for a path that is already registered is a no-op, which
   --  is what keeps a repeated w target from losing the lines written to it
   --  earlier in the same run.
   --
   --  @param Self Registry to extend.
   --  @param Path Destination path exactly as written in the script.
   --  @param Success True when the destination is usable afterwards.
   procedure Create_Destination
     (Self : in out Registry;
      Path : String;
      Success : out Boolean);

   --  Append a line to a destination.
   --
   --  @param Self Registry to write through.
   --  @param Path Destination path exactly as written in the script.
   --  @param Data Bytes to write.
   --  @param Terminator Whether to append a newline.
   --  @param Success True when the bytes reached the file.
   procedure Write
     (Self : in out Registry;
      Path : String;
      Data : String;
      Terminator : Terminator_Policy;
      Success : out Boolean);

   --  Flush and close every destination.
   --
   --  @param Self Registry to close.
   --  @param Success True when every destination closed cleanly.
   procedure Close_All (Self : in out Registry; Success : out Boolean);

   --  Remove and return the diagnostics accumulated so far.
   --
   --  @param Self Registry to drain.
   --  @param Into Diagnostics collected since the previous call.
   procedure Take_Diagnostics
     (Self : in out Registry;
      Into : out Sed.Diagnostics.Diagnostic_List);

   --  @param Self Registry to inspect.
   --  @return Number of registered destinations.
   function Destination_Count (Self : Registry) return Natural;

   --  @param Self Registry to inspect.
   --  @param Path Destination path.
   --  @return True when the path has already been created.
   function Is_Registered (Self : Registry; Path : String) return Boolean;

private

   type Destination is record
      Path : Sed.IO.U.Unbounded_String := Sed.IO.U.Null_Unbounded_String;
      Handle : Sed.IO.File_Handle := Sed.IO.Invalid_Handle;
      --  Set once the destination has failed, so that one broken file does
      --  not produce one diagnostic per written line.
      Broken : Boolean := False;
   end record;

   package Destination_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Destination);

   type Registry is limited new Ada.Finalization.Limited_Controlled with record
      Files : access Sed.IO.Filesystem_Interface'Class := null;
      Items : Destination_Vectors.Vector := Destination_Vectors.Empty_Vector;
      Diagnostics : Sed.Diagnostics.Diagnostic_List :=
        Sed.Diagnostics.Empty_List;
      Closed : Boolean := False;
   end record;

   overriding procedure Finalize (Self : in out Registry);

end Sed.Output.Named_Files;

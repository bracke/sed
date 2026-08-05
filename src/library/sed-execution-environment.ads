with Sedlib.Input;
with Sedlib.Output;
with Sedlib.Resources;
with Sedlib.Text;

--  Adapters that present the program's real environment to the engine.
--
--  sedlib pulls input records, pushes output events and asks for named
--  resources through interfaces it defines. These three adapters implement
--  those interfaces on top of the logical input stream, the standard-output
--  writer and the w destination registry, which is what keeps every layer
--  below this one free of any engine dependency.
--
--  This package and Sed.Scripts.Compilation are the execution and compilation
--  adapters the layering rules allow to name sedlib directly.
package Sed.Execution.Environment is

   --  Supplies input records to the engine from the logical stream.
   type Record_Adapter is
     limited new Sedlib.Input.Record_Source with private;

   --  @param Self Adapter to prepare.
   --  @param Source Logical input stream to pull from.
   procedure Initialize
     (Self : in out Record_Adapter;
      Source : not null access Sed.Input.Logical_Stream.Stream);

   --  @param Self Adapter to inspect.
   --  @return Lines pulled from the stream so far.
   function Lines_Read (Self : Record_Adapter) return Line_Count;

   --  Receives output events from the engine and writes them to standard
   --  output, byte for byte, with no localization and no styling.
   type Sink_Adapter is limited new Sedlib.Output.Event_Sink with private;

   --  @param Self Adapter to prepare.
   --  @param Target Standard output writer.
   procedure Initialize
     (Self : in out Sink_Adapter;
      Target : not null access Sed.Output.Standard.Writer);

   --  Serves r reads and w writes.
   type Resource_Adapter is
     limited new Sedlib.Resources.Resource_Provider with private;

   --  @param Self Adapter to prepare.
   --  @param Files Filesystem used to read r files.
   --  @param Named Registry owning the w destinations.
   procedure Initialize
     (Self : in out Resource_Adapter;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Named : not null access Sed.Output.Named_Files.Registry);

   --  Remove and return diagnostics the resource adapter accumulated.
   --
   --  @param Self Adapter to drain.
   --  @param Into Diagnostics collected since the previous call.
   procedure Take_Diagnostics
     (Self : in out Resource_Adapter;
      Into : out Sed.Diagnostics.Diagnostic_List);

private

   type Record_Adapter is limited new Sedlib.Input.Record_Source with record
      Source : access Sed.Input.Logical_Stream.Stream := null;
      Count : Line_Count := 0;
   end record;

   overriding function Read
     (Source : in out Record_Adapter) return Sedlib.Input.Read_Result;

   type Sink_Adapter is limited new Sedlib.Output.Event_Sink with record
      Target : access Sed.Output.Standard.Writer := null;
   end record;

   overriding function Emit
     (Sink : in out Sink_Adapter;
      Event : Sedlib.Output.Output_Event) return Sedlib.Output.Sink_Result;

   type Resource_Adapter is
     limited new Sedlib.Resources.Resource_Provider with record
      Files : access Sed.IO.Filesystem_Interface'Class := null;
      Named : access Sed.Output.Named_Files.Registry := null;
      Diagnostics : Sed.Diagnostics.Diagnostic_List :=
        Sed.Diagnostics.Empty_List;
   end record;

   overriding function Read_All
     (Provider : in out Resource_Adapter;
      Name : String) return Sedlib.Resources.Resource_Result;

   overriding function Read_Record
     (Provider : in out Resource_Adapter;
      Name : String) return Sedlib.Resources.Resource_Result;

   overriding function Write_All
     (Provider : in out Resource_Adapter;
      Name : String;
      Text : Sedlib.Text.Text_Value;
      Has_Terminator : Boolean) return Sedlib.Resources.Resource_Result;

   overriding function Write_First_Line
     (Provider : in out Resource_Adapter;
      Name : String;
      Text : Sedlib.Text.Text_Value;
      Has_Terminator : Boolean) return Sedlib.Resources.Resource_Result;

end Sed.Execution.Environment;

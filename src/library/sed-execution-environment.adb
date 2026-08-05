
package body Sed.Execution.Environment is

   package D renames Sed.Diagnostics;
   package LS renames Sed.Input.Logical_Stream;

   use type Sed.IO.IO_Status;
   use type Sed.Input.Record_Status;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : in out Record_Adapter;
      Source : not null access LS.Stream) is
   begin
      Self.Source := Source;
      Self.Count := 0;
   end Initialize;

   ----------------
   -- Lines_Read --
   ----------------

   function Lines_Read (Self : Record_Adapter) return Line_Count is
   begin
      return Self.Count;
   end Lines_Read;

   ----------
   -- Read --
   ----------

   overriding function Read
     (Source : in out Record_Adapter) return Sedlib.Input.Read_Result
   is
      Item : Sed.Input.Input_Line;
      Status : Sed.Input.Record_Status;
   begin
      if Source.Source = null then
         return (Status => Sedlib.Input.End_Of_Input, others => <>);
      end if;

      LS.Next (Source.Source.all, Item, Status);

      case Status is
         when Sed.Input.Record_Available =>
            Source.Count := Source.Count + 1;

            return
              (Status => Sedlib.Input.Record_Available,
               Item =>
                 (Text =>
                    Sedlib.Text.To_Text (Sed.Input.U.To_String (Item.Data)),
                  Has_Terminator => Item.Has_Terminator,
                  Source_Name =>
                    Sedlib.Text.To_Text
                      (Sed.Input.U.To_String (Item.Source_Name))),
               others => <>);

         when Sed.Input.End_Of_Input =>
            return (Status => Sedlib.Input.End_Of_Input, others => <>);

         when Sed.Input.Read_Failed =>
            --  The stream has already recorded a structured diagnostic; the
            --  engine only needs to know that no further record is coming.
            return (Status => Sedlib.Input.Read_Failed, others => <>);
      end case;
   end Read;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : in out Sink_Adapter;
      Target : not null access Sed.Output.Standard.Writer) is
   begin
      Self.Target := Target;
   end Initialize;

   ----------
   -- Emit --
   ----------

   overriding function Emit
     (Sink : in out Sink_Adapter;
      Event : Sedlib.Output.Output_Event) return Sedlib.Output.Sink_Result is
   begin
      if Sink.Target = null then
         return (Status => Sedlib.Output.Rejected, others => <>);
      end if;

      --  Every event kind is program data and reaches standard output
      --  unchanged. The event kind matters to the engine, not to the bytes.
      Sed.Output.Standard.Write
        (Sink.Target.all,
         Sedlib.Text.To_String (Event.Text),
         Sed.Output.Policy_For (Event.Has_Terminator));

      if Sed.Output.Standard.Failed (Sink.Target.all) then
         return (Status => Sedlib.Output.Rejected, others => <>);
      end if;

      return (Status => Sedlib.Output.Accepted, others => <>);
   end Emit;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self : in out Resource_Adapter;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Named : not null access Sed.Output.Named_Files.Registry) is
   begin
      Self.Files := Files;
      Self.Named := Named;
      Self.Diagnostics := D.Empty_List;
   end Initialize;

   ----------------------
   -- Take_Diagnostics --
   ----------------------

   procedure Take_Diagnostics
     (Self : in out Resource_Adapter;
      Into : out D.Diagnostic_List) is
   begin
      Into := Self.Diagnostics;
      Self.Diagnostics := D.Empty_List;
   end Take_Diagnostics;

   --------------
   -- Read_All --
   --------------

   overriding function Read_All
     (Provider : in out Resource_Adapter;
      Name : String) return Sedlib.Resources.Resource_Result
   is
      Content : Sed.IO.U.Unbounded_String;
      Result : Sed.IO.IO_Result;
   begin
      if Provider.Files = null then
         return (Status => Sedlib.Resources.Resource_Success, others => <>);
      end if;

      Provider.Files.Read_Whole_File (Name, Content, Result);

      if Sed.IO.Is_Failure (Result) then
         if Result.Status = Sed.IO.IO_Failure then
            --  The file opened but could not be read through. POSIX defines
            --  no error status for r, so this is a warning: the output is
            --  incomplete but the run continues and its status is unchanged.
            declare
               Item : D.Diagnostic :=
                 D.Make (D.Read_Resource_Failed, D.Path_At (Name));
            begin
               D.Set (Item, D.Path, Name);
               D.Append (Provider.Diagnostics, Item);
            end;
         end if;

         --  POSIX: an rfile that does not exist or cannot be read is treated
         --  as an empty file, causing no error condition.
         return (Status => Sedlib.Resources.Resource_Success, others => <>);
      end if;

      declare
         Text : constant String := Sed.IO.U.To_String (Content);
         Terminated : constant Boolean :=
           Text'Length > 0 and then Text (Text'Last) = ASCII.LF;
         Payload : constant String :=
           (if Terminated then Text (Text'First .. Text'Last - 1) else Text);
      begin
         return
           (Status => Sedlib.Resources.Resource_Success,
            Text => Sedlib.Text.To_Text (Payload),
            Has_Terminator => Terminated,
            others => <>);
      end;
   end Read_All;

   -----------------
   -- Read_Record --
   -----------------

   overriding function Read_Record
     (Provider : in out Resource_Adapter;
      Name : String) return Sedlib.Resources.Resource_Result is
   begin
      --  POSIX sed has no single-record read command. The engine exposes one
      --  for extensions; serving it from the whole file keeps the provider
      --  total rather than letting an unreachable path go unimplemented.
      return Read_All (Provider, Name);
   end Read_Record;

   ---------------
   -- Write_All --
   ---------------

   overriding function Write_All
     (Provider : in out Resource_Adapter;
      Name : String;
      Text : Sedlib.Text.Text_Value;
      Has_Terminator : Boolean) return Sedlib.Resources.Resource_Result
   is
      Success : Boolean;
   begin
      if Provider.Named = null then
         return (Status => Sedlib.Resources.Operation_Failed, others => <>);
      end if;

      Sed.Output.Named_Files.Write
        (Provider.Named.all,
         Name,
         Sedlib.Text.To_String (Text),
         Sed.Output.Policy_For (Has_Terminator),
         Success);

      if not Success then
         return (Status => Sedlib.Resources.Operation_Failed, others => <>);
      end if;

      return (Status => Sedlib.Resources.Resource_Success, others => <>);
   end Write_All;

   ----------------------
   -- Write_First_Line --
   ----------------------

   overriding function Write_First_Line
     (Provider : in out Resource_Adapter;
      Name : String;
      Text : Sedlib.Text.Text_Value;
      Has_Terminator : Boolean) return Sedlib.Resources.Resource_Result is
   begin
      --  The engine has already reduced the pattern space to its first line.
      return Write_All (Provider, Name, Text, Has_Terminator);
   end Write_First_Line;

end Sed.Execution.Environment;

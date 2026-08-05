with Sedlib.Diagnostics;
with Sedlib.Execution;
with Sedlib.Options;
with Sed.Engine;
with Sed.Execution.Environment;
with Sed.Scripts.Compilation.Engine;

package body Sed.Execution is

   package D renames Sed.Diagnostics;

   --  Execution options for a general-purpose command-line sed.
   --
   --  The engine enforces finite bounds by design. A library embedding it in
   --  a server wants those bounds small; a command-line stream editor must be
   --  able to process whatever the host can hold, so they are raised to
   --  effectively unbounded values here. The mechanism stays in place: a
   --  script that still exceeds one gets a structured Resource_Exhausted
   --  diagnostic rather than a truncated result.
   function Command_Line_Options
     (Suppress_Automatic_Output : Boolean)
      return Sedlib.Options.Execution_Options;

   --------------------------
   -- Command_Line_Options --
   --------------------------

   function Command_Line_Options
     (Suppress_Automatic_Output : Boolean)
      return Sedlib.Options.Execution_Options
   is
      Options : Sedlib.Options.Execution_Options :=
        Sedlib.Options.Default_Execution_Options;

      --  One gibibyte for byte-valued bounds, and the widest count the engine
      --  accepts for event and instruction bounds.
      Byte_Bound : constant Natural := 2 ** 30;

      Limits : constant Sedlib.Options.Execution_Limits :=
        (Input_Record_Bytes => Byte_Bound,
         Pattern_Space_Bytes => Byte_Bound,
         Hold_Space_Bytes => Byte_Bound,
         Pending_Append_Bytes => Byte_Bound,
         Pending_Append_Events => Natural'Last,
         Output_Bytes => Natural'Last,
         Output_Events => Natural'Last,
         Total_Instructions => Natural'Last,
         Instructions_Per_Cycle => Natural'Last,
         Branches_Per_Cycle => Natural'Last,
         Input_Records => Natural'Last,
         Cycles => Natural'Last,
         Regexp_Steps => Natural'Last);
   begin
      Sedlib.Options.Set_Automatic_Output
        (Options, not Suppress_Automatic_Output);
      Sedlib.Options.Set_Text_Mode (Options, Sedlib.Options.Byte_Mode);
      Sedlib.Options.Set_UTF8_Policy
        (Options, Sedlib.Options.Treat_Invalid_As_Bytes);
      Sedlib.Options.Set_Resource_Preflight
        (Options, Sedlib.Options.Fail_When_Executed);
      Sedlib.Options.Set_Callback_Policy
        (Options, Sedlib.Options.Convert_Callback_Exceptions);
      Sedlib.Options.Set_Limits (Options, Limits);
      return Options;
   end Command_Line_Options;

   ---------
   -- Run --
   ---------

   procedure Run
     (Program : Sed.Scripts.Compilation.Compiled_Program;
      Suppress_Automatic_Output : Boolean;
      Source : not null access Sed.Input.Logical_Stream.Stream;
      Target : not null access Sed.Output.Standard.Writer;
      Named : not null access Sed.Output.Named_Files.Registry;
      Files : not null access Sed.IO.Filesystem_Interface'Class;
      Result : out Outcome)
   is
      use type Sedlib.Execution.Termination_Reason;

      Records : aliased Environment.Record_Adapter;
      Sink : aliased Environment.Sink_Adapter;
      Resources : aliased Environment.Resource_Adapter;

      Engine_Result : Sedlib.Execution.Execution_Result;
      Reported : Sed.Diagnostics.Diagnostic_List;
   begin
      Result := (Succeeded => False,
                 Diagnostics => D.Empty_List,
                 Lines_Read => 0);

      Environment.Initialize (Records, Source);
      Environment.Initialize (Sink, Target);
      Environment.Initialize (Resources, Files, Named);

      Sedlib.Execution.Execute
        (Program => Sed.Scripts.Compilation.Engine.Program_Of (Program),
         Source => Records,
         Sink => Sink,
         Options => Command_Line_Options (Suppress_Automatic_Output),
         Result => Engine_Result,
         Resources => Resources'Access);

      Result.Lines_Read := Environment.Lines_Read (Records);

      --  Diagnostics the input stream and the resource adapter produced while
      --  the engine was running are part of this run's outcome.
      Sed.Input.Logical_Stream.Take_Diagnostics (Source.all, Reported);

      for Index in 1 .. D.Length (Reported) loop
         D.Append (Result.Diagnostics, D.Element (Reported, Index));
      end loop;

      Environment.Take_Diagnostics (Resources, Reported);

      for Index in 1 .. D.Length (Reported) loop
         D.Append (Result.Diagnostics, D.Element (Reported, Index));
      end loop;

      Sed.Output.Named_Files.Take_Diagnostics (Named.all, Reported);

      for Index in 1 .. D.Length (Reported) loop
         D.Append (Result.Diagnostics, D.Element (Reported, Index));
      end loop;

      --  Then whatever the engine itself reported.
      declare
         use type D.Diagnostic_Code;

         Engine_Diagnostics : constant Sedlib.Diagnostics.Diagnostic_List :=
           Engine_Result.Diagnostics;

         --  When the standard-output writer has failed, the engine also
         --  reports that its sink rejected a write. Only one of the two is
         --  news, and the writer is the one that knows why.
         Output_Already_Reported : constant Boolean :=
           Sed.Output.Standard.Failed (Target.all);
      begin
         for Index in 1 .. Sedlib.Diagnostics.Length (Engine_Diagnostics) loop
            declare
               Item : constant Sedlib.Diagnostics.Diagnostic :=
                 Sedlib.Diagnostics.Element (Engine_Diagnostics, Index);
               Translated : constant D.Diagnostic := Sed.Engine.Translate (Item);
            begin
               if Sed.Engine.Is_Reportable (Item)
                 and then not (Output_Already_Reported
                               and then D.Code (Translated)
                                        = D.Standard_Output_Failed)
               then
                  D.Append_Unique (Result.Diagnostics, Translated);
               end if;
            end;
         end loop;
      end;

      if Sed.Output.Standard.Failed (Target.all) then
         D.Append_Unique
           (Result.Diagnostics, Sed.Output.Standard.Failure (Target.all));
      end if;

      --  q and Q are ordinary, successful terminations; only a genuine fault
      --  makes the run unsuccessful.
      Result.Succeeded :=
        Engine_Result.Succeeded
        or else Engine_Result.Termination = Sedlib.Execution.Quit_Command
        or else Engine_Result.Termination =
                  Sedlib.Execution.Quit_Without_Output_Command;

      if Sed.Output.Standard.Failed (Target.all) then
         Result.Succeeded := False;
      end if;
   end Run;

end Sed.Execution;

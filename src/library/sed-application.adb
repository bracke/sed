with Ada.Command_Line;
with Ada.Exceptions;
with Sed.Command_Line.Options;
with Sed.Command_Line.Validation;
with Sed.Configuration;
with Sed.Diagnostics.Rendering;
with Sed.Execution;
with Sed.Help;
with Sed.Input.Logical_Stream;
with Sed.IO.Filesystem;
with Sed.IO.Process_Streams;
with Sed.Localization;
with Sed.Output.Named_Files;
with Sed.Output.Standard;
with Sed.Scripts.Compilation;
with Sed.Scripts.Loading;
with Sed.Terminal;

package body Sed.Application is

   package CL renames Sed.Command_Line;
   package D renames Sed.Diagnostics;
   package L renames Sed.Localization;
   package T renames Sed.Terminal;

   use type CL.Invocation_Mode;
   use type CL.Operand_Kind;
   use type CL.Script_Source_Kind;
   use type D.Diagnostic_Code;
   use type Sed.Status.Outcome;

   -------------
   -- Execute --
   -------------

   function Execute
     (Arguments : CL.Arguments.Argument_List'Class;
      Standard_In : in out Sed.IO.Input_Source_Interface'Class;
      Standard_Out : in out Sed.IO.Output_Stream_Interface'Class;
      Standard_Err : in out Sed.IO.Output_Stream_Interface'Class;
      Filesystem : in out Sed.IO.Filesystem_Interface'Class;
      Context : Sed.Environment.Process_Environment)
      return Application_Status
   is
      Status : Sed.Status.Accumulator := Sed.Status.Initial;

      Catalog : L.Catalog;
      Error_Policy : T.Style_Policy := T.Plain;

      --  Write one line to standard error. A failure to report a failure has
      --  nowhere left to go, so it is folded into the status and dropped.
      procedure Put_Error (Text : String);

      --  Render one diagnostic to standard error and fold in its status.
      procedure Emit (Item : D.Diagnostic);

      --  Render a whole list of diagnostics.
      procedure Emit_All (List : D.Diagnostic_List);

      --  Write the hint that points at --help.
      procedure Emit_Hint;

      ---------------
      -- Put_Error --
      ---------------

      procedure Put_Error (Text : String) is
         Result : Sed.IO.IO_Result;
      begin
         Standard_Err.Write (Text & ASCII.LF, Result);

         if Sed.IO.Is_Failure (Result) then
            Sed.Status.Record_Outcome (Status, Sed.Status.Processing_Failure);
         end if;
      end Put_Error;

      ----------
      -- Emit --
      ----------

      procedure Emit (Item : D.Diagnostic) is
      begin
         Put_Error (D.Rendering.Render (Item, Catalog, Error_Policy));

         declare
            Note : constant String :=
              D.Rendering.Render_Related (Item, Catalog, Error_Policy);
         begin
            if Note'Length > 0 then
               Put_Error (Note);
            end if;
         end;

         Sed.Status.Record_Outcome (Status, D.Status_Effect (Item));
      end Emit;

      --------------
      -- Emit_All --
      --------------

      procedure Emit_All (List : D.Diagnostic_List) is
      begin
         for Index in 1 .. D.Length (List) loop
            Emit (D.Element (List, Index));
         end loop;
      end Emit_All;

      ----------------
      -- Emit_Hint --
      ----------------

      procedure Emit_Hint is
      begin
         Put_Error (D.Rendering.Render_Hint (Catalog, Error_Policy));
      end Emit_Hint;

      Tokens : constant CL.Token_Parse := CL.Options.Parse (Arguments);

   begin
      --  Styling and the catalogue are resolved before anything can fail, and
      --  from whatever the command line managed to say about colour, so even
      --  the first malformed option is reported the way the user asked for.
      Error_Policy :=
        Sed.Configuration.Error_Style
          (Choice => CL.Color (Tokens),
           Explicit => CL.Color_Was_Explicit (Tokens),
           Context => Context);

      L.Initialize
        (Catalog,
         Sed.Environment.U.To_String (Context.Catalog_Path),
         Sed.Environment.U.To_String (Context.Locale));

      declare
         Parsed : constant CL.Parse_Result := CL.Validation.Validate (Tokens);
      begin
         if not CL.Succeeded (Parsed) then
            Emit (CL.Failure (Parsed));
            Emit_Hint;
            return Sed.Status.Current (Status);
         end if;

         declare
            Invocation : constant CL.Invocation := CL.Value (Parsed);
            Settings : constant Sed.Configuration.Settings :=
              Sed.Configuration.Resolve (Invocation, Context);
         begin
            Error_Policy := Sed.Configuration.Error_Style (Settings);

            --  Administrative modes finish here, before any script is loaded
            --  and before any file is opened or created.
            if Sed.Configuration.Mode (Settings) /= CL.Run_Mode then
               declare
                  Written : Boolean;
               begin
                  if Sed.Configuration.Mode (Settings) = CL.Help_Mode then
                     Sed.Help.Write_Help
                       (Standard_Out,
                        Catalog,
                        Sed.Configuration.Output_Style (Settings),
                        Written);
                  else
                     Sed.Help.Write_Version
                       (Standard_Out,
                        Catalog,
                        Sed.Configuration.Output_Style (Settings),
                        Written);
                  end if;

                  declare
                     Result : Sed.IO.IO_Result;
                  begin
                     Standard_Out.Flush (Result);

                     if Sed.IO.Is_Failure (Result) or else not Written then
                        Emit (D.Make (D.Standard_Output_Failed));
                     end if;
                  end;
               end;

               return Sed.Status.Current (Status);
            end if;

            --  Load every script source, in exact command-line order.
            declare
               Sources : Sed.Scripts.Source_Set := Sed.Scripts.Empty_Set;
            begin
               for Index in 1 .. CL.Script_Count (Invocation) loop
                  declare
                     Declaration : constant CL.Script_Declaration :=
                       CL.Script (Invocation, Index);
                     Text : constant String :=
                       CL.U.To_String (Declaration.Value);
                  begin
                     if Declaration.Kind = CL.Inline_Expression then
                        Sed.Scripts.Append
                          (Set => Sources,
                           Kind => Sed.Scripts.Inline_Expression,
                           Content => Text,
                           Occurrence => Declaration.Occurrence,
                           Argument_Index => Declaration.Argument_Index,
                           Ordinal => Declaration.Ordinal,
                           Positional => Declaration.Positional);
                     else
                        declare
                           Item : D.Diagnostic;
                           Loaded : Boolean;
                        begin
                           Sed.Scripts.Loading.Load_File
                             (Set => Sources,
                              Files => Filesystem,
                              Path => Text,
                              Occurrence => Declaration.Occurrence,
                              Argument_Index => Declaration.Argument_Index,
                              Ordinal => Declaration.Ordinal,
                              Diagnostic => Item,
                              Success => Loaded);

                           if not Loaded then
                              --  An unreadable script file is fatal before any
                              --  input operand is opened.
                              Emit (Item);
                              return Sed.Status.Current (Status);
                           end if;
                        end;
                     end if;
                  end;
               end loop;

               --  Compile before touching any file the script names.
               declare
                  Program : Sed.Scripts.Compilation.Compiled_Program;
                  Compile_Diagnostics : D.Diagnostic_List;
                  Compiled : Boolean;
               begin
                  Sed.Scripts.Compilation.Compile
                    (Set => Sources,
                     Program => Program,
                     Diagnostics => Compile_Diagnostics,
                     Success => Compiled);

                  Emit_All (Compile_Diagnostics);

                  if not Compiled then
                     if not Sed.Status.Failed (Status) then
                        --  The engine refused the script without saying why.
                        Emit (D.Make (D.Script_Syntax_Error));
                     end if;

                     return Sed.Status.Current (Status);
                  end if;

                  --  Compilation succeeded, so w destinations may now be
                  --  created. Each one is truncated exactly once.
                  declare
                     --  These own the run's resources and outlive every call
                     --  that is handed a reference to them.
                     Named : aliased Sed.Output.Named_Files.Registry;
                     Target : aliased Sed.Output.Standard.Writer;
                     Source : aliased Sed.Input.Logical_Stream.Stream;
                     Created : Boolean;
                  begin
                     Sed.Output.Named_Files.Initialize
                       (Named, Filesystem'Unchecked_Access);

                     for Index in
                       1 .. Sed.Scripts.Compilation.Write_Destination_Count
                              (Program)
                     loop
                        Sed.Output.Named_Files.Create_Destination
                          (Named,
                           Sed.Scripts.Compilation.Write_Destination
                             (Program, Index),
                           Created);
                     end loop;

                     declare
                        Reported : D.Diagnostic_List;
                     begin
                        Sed.Output.Named_Files.Take_Diagnostics
                          (Named, Reported);
                        Emit_All (Reported);

                        if D.Has_Errors (Reported) then
                           declare
                              Closed : Boolean;
                           begin
                              Sed.Output.Named_Files.Close_All (Named, Closed);
                           end;

                           return Sed.Status.Current (Status);
                        end if;
                     end;

                     Sed.Output.Standard.Initialize
                       (Target, Standard_Out'Unchecked_Access);

                     Sed.Input.Logical_Stream.Initialize
                       (Source,
                        Filesystem'Unchecked_Access,
                        Standard_In'Unchecked_Access);

                     if CL.Operand_Count (Invocation) = 0 then
                        --  No operand means standard input, which POSIX
                        --  requires of a bare invocation.
                        Sed.Input.Logical_Stream.Add_Operand
                          (Source,
                           (Kind => Sed.Input.Standard_Input,
                            Name => CL.U.To_Unbounded_String ("-")));
                     else
                        for Index in 1 .. CL.Operand_Count (Invocation) loop
                           declare
                              Item : constant CL.Input_Operand :=
                                CL.Operand (Invocation, Index);
                           begin
                              Sed.Input.Logical_Stream.Add_Operand
                                (Source,
                                 (Kind =>
                                    (if Item.Kind = CL.Standard_Input
                                     then Sed.Input.Standard_Input
                                     else Sed.Input.Named_File),
                                  Name => Item.Name));
                           end;
                        end loop;
                     end if;

                     declare
                        Result : Sed.Execution.Outcome;
                     begin
                        Sed.Execution.Run
                          (Program => Program,
                           Suppress_Automatic_Output =>
                             Sed.Configuration.Suppress_Automatic_Output
                               (Settings),
                           Source => Source'Unchecked_Access,
                           Target => Target'Unchecked_Access,
                           Named => Named'Unchecked_Access,
                           Files => Filesystem'Unchecked_Access,
                           Result => Result);

                        Emit_All (Result.Diagnostics);

                        if not Result.Succeeded
                          and then not Sed.Status.Failed (Status)
                        then
                           Emit (D.Make (D.Execution_Failed));
                        end if;
                     end;

                     --  Flush and close in a fixed order, and report every
                     --  cleanup failure rather than letting finalization
                     --  swallow it.
                     Sed.Output.Standard.Flush (Target);

                     if Sed.Output.Standard.Failed (Target) then
                        Sed.Status.Record_Outcome
                          (Status, Sed.Status.Processing_Failure);
                     end if;

                     declare
                        Closed : Boolean;
                        Reported : D.Diagnostic_List;
                     begin
                        Sed.Output.Named_Files.Close_All (Named, Closed);
                        Sed.Output.Named_Files.Take_Diagnostics
                          (Named, Reported);
                        Emit_All (Reported);
                     end;

                     declare
                        Reported : D.Diagnostic_List;
                     begin
                        Sed.Input.Logical_Stream.Take_Diagnostics
                          (Source, Reported);
                        Emit_All (Reported);
                     end;

                     Sed.Input.Logical_Stream.Close (Source);
                  end;
               end;
            end;
         end;
      end;

      return Sed.Status.Current (Status);

   exception
      when Unexpected : others =>
         --  Every expected failure has already been converted into a
         --  structured diagnostic further down. Anything arriving here --
         --  Storage_Error, a Constraint_Error provoked by external input, or
         --  an unexpected engine fault -- is contained: one localized
         --  internal-error diagnostic, internal-failure status, and no Ada
         --  traceback. Execution does not continue.
         declare
            Item : D.Diagnostic := D.Make (D.Internal_Error);
         begin
            if Context.Development_Diagnostics then
               --  Development diagnostic mode only. A normal run never shows
               --  an exception name or a traceback.
               D.Set
                 (Item,
                  D.Detail,
                  Ada.Exceptions.Exception_Information (Unexpected));
            end if;

            Emit (Item);
         end;

         Sed.Status.Record_Outcome (Status, Sed.Status.Internal_Failure);
         return Sed.Status.Current (Status);
   end Execute;

   ---------
   -- Run --
   ---------

   procedure Run (Status : out Sed.Status.Exit_Status) is
      Outcome : Application_Status := Sed.Status.Internal_Failure;
   begin
      declare
         List : CL.Arguments.Fixed_List;
         Standard_In : Sed.IO.Process_Streams.Process_Input;
         Standard_Out : Sed.IO.Process_Streams.Process_Output
           (Sed.IO.Process_Streams.Output_Channel);
         Standard_Err : Sed.IO.Process_Streams.Process_Output
           (Sed.IO.Process_Streams.Error_Channel);
         Files : Sed.IO.Filesystem.Host_Filesystem;
         Context : constant Sed.Environment.Process_Environment :=
           Sed.Environment.Capture;
      begin
         --  The one place that reads the real argument vector.
         for Index in 1 .. Ada.Command_Line.Argument_Count loop
            CL.Arguments.Append (List, Ada.Command_Line.Argument (Index));
         end loop;

         Outcome :=
           Execute
             (Arguments => List,
              Standard_In => Standard_In,
              Standard_Out => Standard_Out,
              Standard_Err => Standard_Err,
              Filesystem => Files,
              Context => Context);
      end;

      Status := Sed.Status.Status_Of (Outcome);
   end Run;

end Sed.Application;

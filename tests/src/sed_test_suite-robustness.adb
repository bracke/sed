with AUnit.Assertions;
with Sed.Application;
with Sed.Command_Line.Arguments;
with Sed.Diagnostics;
with Sed.Diagnostics.Quoting;
with Sed.Diagnostics.Registry;
with Sed.Engine;
with Sedlib.Diagnostics;
with Sed.Status;
with Sed.Terminal;
with Sed_Registries;
with Sed_Test_Suite.Doubles;
with Sed_Test_Suite.Support;

package body Sed_Test_Suite.Robustness is

   use AUnit.Assertions;
   use Sed_Test_Suite.Support;

   package D renames Sed.Diagnostics;
   package T renames Sed.Terminal;

   use type D.Diagnostic_Code;
   use type D.Recoverability;
   use type D.Severity;
   use type Sed.Status.Exit_Status;
   use type Sed.Status.Outcome;
   use type Sed.Line_Count;

   LF : constant Character := ASCII.LF;

   overriding function Name (Test : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (Test);
   begin
      return AUnit.Format ("sed robustness");
   end Name;

   --  STATUS-001: the accumulator never lets a failure be erased.

   procedure Status_Is_Monotonic
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Item : Sed.Status.Accumulator := Sed.Status.Initial;
   begin
      Assert
        (Sed.Status.Current (Item) = Sed.Status.Success,
         "STATUS-001 a fresh accumulator reports success");

      Sed.Status.Record_Outcome (Item, Sed.Status.Processing_Failure);
      Sed.Status.Record_Outcome (Item, Sed.Status.Success);
      Assert
        (Sed.Status.Current (Item) = Sed.Status.Processing_Failure,
         "STATUS-001 a later success does not erase a failure");

      Sed.Status.Record_Outcome (Item, Sed.Status.Invocation_Failure);
      Assert
        (Sed.Status.Current (Item) = Sed.Status.Invocation_Failure,
         "STATUS-001 a higher-precedence failure wins");

      Sed.Status.Record_Outcome (Item, Sed.Status.Processing_Failure);
      Assert
        (Sed.Status.Current (Item) = Sed.Status.Invocation_Failure,
         "STATUS-001 a lower-precedence failure does not lower the outcome");

      Assert
        (Sed.Status.Status_Of (Sed.Status.Success) = 0
           and then Sed.Status.Status_Of (Sed.Status.Processing_Failure) = 1
           and then Sed.Status.Status_Of (Sed.Status.Invocation_Failure) = 2
           and then Sed.Status.Status_Of (Sed.Status.Internal_Failure) = 3,
         "STATUS-001 the exit status mapping is the documented one");
   end Status_Is_Monotonic;

   --  DIAG-REGISTRY-001: every code has exactly one usable descriptor.

   procedure Registry_Is_Complete
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      for Code in D.Diagnostic_Code loop
         declare
            Descriptor : constant D.Registry.Code_Descriptor :=
              D.Registry.Descriptor (Code);
            Key : constant String := D.Registry.Message_Key (Code);
            Label : constant String := D.Diagnostic_Code'Image (Code);
         begin
            Assert (Key'Length > 0, Label & " has a message key");
            Assert
              (Contains (Key, "sed."),
               Label & " uses a namespaced message key");

            --  A required parameter must also be an accepted one, otherwise
            --  no diagnostic could ever satisfy its own schema.
            for Name in D.Parameter_Name loop
               if Descriptor.Required (Name) then
                  Assert
                    (D.Registry.Accepted (Code) (Name),
                     Label & " accepts every parameter it requires");
               end if;
            end loop;

            --  Only an internal failure may claim the internal exit status.
            if Descriptor.Status_Effect = Sed.Status.Internal_Failure then
               Assert
                 (Code = D.Internal_Error,
                  Label & " does not claim the internal status");
            end if;

            --  A warning must not by itself fail the run.
            if Descriptor.Severity = D.Warning then
               Assert
                 (Descriptor.Status_Effect = Sed.Status.Success,
                  Label & " is a warning without a status effect");
               Assert
                 (Descriptor.Recoverability = D.Recoverable,
                  Label & " is a recoverable warning");
            end if;
         end;
      end loop;
   end Registry_Is_Complete;

   --  DIAG-SCHEMA-001: a diagnostic satisfies its schema once its required
   --  parameters are supplied, and rejects a parameter it does not accept.

   procedure Diagnostic_Schema_Is_Enforced
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Item : D.Diagnostic := D.Make (D.Unknown_Option);
   begin
      Assert
        (not D.Schema_Satisfied (Item),
         "DIAG-SCHEMA-001 a missing required parameter fails the schema");

      D.Set (Item, D.Option, "-x");
      Assert
        (D.Schema_Satisfied (Item),
         "DIAG-SCHEMA-001 supplying the requirement satisfies the schema");
      Assert
        (D.Text_Of (Item, D.Option) = "-x",
         "DIAG-SCHEMA-001 the raw value is stored unchanged");

      D.Set (Item, D.Capability, "unrelated");
      Assert
        (not D.Schema_Satisfied (Item),
         "DIAG-SCHEMA-001 an unaccepted parameter fails the schema");
   end Diagnostic_Schema_Is_Enforced;

   --  DIAG-ESCAPE-001: untrusted values cannot reach the terminal unescaped.

   procedure Quoting_Neutralizes_Untrusted_Values
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Escape : constant String := [1 => ASCII.ESC];
   begin
      Assert
        (D.Quoting.Escape (Escape & "[31m") = "\e[31m",
         "DIAG-ESCAPE-001 an escape character is neutralized");
      Assert
        (D.Quoting.Escape ("a" & LF & "b") = "a\nb",
         "DIAG-ESCAPE-001 a newline cannot split a diagnostic line");
      Assert
        (D.Quoting.Escape ("a" & ASCII.CR) = "a\r",
         "DIAG-ESCAPE-001 a carriage return cannot rewrite the line");
      Assert
        (D.Quoting.Escape ("a\b") = "a\\b",
         "DIAG-ESCAPE-001 a backslash is doubled");
      Assert
        (D.Quoting.Escape ("a" & ASCII.NUL) = "a\0",
         "DIAG-ESCAPE-001 an embedded NUL is visible");
      Assert
        (D.Quoting.Escape ([1 => Character'Val (16#7F#)]) = "\x7F",
         "DIAG-ESCAPE-001 DEL is escaped as hex");
      Assert
        (D.Quoting.Escape ("plain/path") = "plain/path",
         "DIAG-ESCAPE-001 an ordinary path is unchanged");
      Assert
        (D.Quoting.Is_Safe ("plain") and then not D.Quoting.Is_Safe (Escape),
         "DIAG-ESCAPE-001 safety agrees with escaping");
      Assert
        (D.Quoting.Quoted ("") = "''",
         "DIAG-ESCAPE-001 an empty value stays visible when quoted");

      --  Well-formed UTF-8 passes through so non-ASCII paths stay readable,
      --  while an ill-formed byte is escaped rather than emitted raw.
      Assert
        (D.Quoting.Escape ([Character'Val (16#C3#), Character'Val (16#A6#)]) =
           [Character'Val (16#C3#), Character'Val (16#A6#)],
         "DIAG-ESCAPE-001 well-formed UTF-8 is preserved");
      Assert
        (D.Quoting.Escape ([1 => Character'Val (16#FF#)]) = "\xFF",
         "DIAG-ESCAPE-001 an ill-formed byte is escaped");
   end Quoting_Neutralizes_Untrusted_Values;

   --  DIAG-ESCAPE-002: the escaping reaches rendered output.

   procedure Rendered_Diagnostics_Are_Escaped
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Hostile : constant String := [1 => ASCII.ESC] & "[31mred";
      Result : constant Run_Result := Run ([A ("-" & "y"), A ("p")]);
      Files : Doubles.Memory_Filesystem;
      Injected : constant Run_Result :=
        Run ([A ("-f"), A (Hostile)], Files);
   begin
      Assert
        (Result.Exit_Status = 2,
         "DIAG-ESCAPE-002 an unknown option is an invocation failure");

      for Item of Errors (Injected) loop
         Assert
           (Item /= ASCII.ESC,
            "DIAG-ESCAPE-002 no escape character reaches standard error");
      end loop;

      Assert
        (Contains (Errors (Injected), "\e[31mred"),
         "DIAG-ESCAPE-002 the hostile path is shown escaped");
   end Rendered_Diagnostics_Are_Escaped;

   --  STYLE-001: styling changes bytes but never information.

   procedure Styling_Preserves_Information
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Plain : constant Run_Result :=
        Run ([A ("--color=never"), A ("-x")]);
      Styled : constant Run_Result :=
        Run ([A ("--color=always"), A ("-x")]);
      Auto_Not_Terminal : constant Run_Result :=
        Run ([A ("--color=auto"), A ("-x")]);

      --  Remove every ANSI escape sequence from Text.
      function Stripped (Text : String) return String;

      --------------
      -- Stripped --
      --------------

      function Stripped (Text : String) return String is
         Result : U.Unbounded_String;
         Index : Natural := Text'First;
      begin
         while Index <= Text'Last loop
            if Text (Index) = ASCII.ESC then
               while Index <= Text'Last and then Text (Index) /= 'm' loop
                  Index := Index + 1;
               end loop;
            else
               U.Append (Result, Text (Index));
            end if;

            Index := Index + 1;
         end loop;

         return U.To_String (Result);
      end Stripped;

   begin
      Assert
        (not Contains (Output (Plain) & Errors (Plain), [1 => ASCII.ESC]),
         "STYLE-001 never emits no escape sequences");
      Assert
        (Contains (Errors (Styled), [1 => ASCII.ESC]),
         "STYLE-001 always emits escape sequences");
      Assert
        (Stripped (Errors (Styled)) = Errors (Plain),
         "STYLE-001 styled and plain diagnostics carry the same text");
      Assert
        (not Contains (Errors (Auto_Not_Terminal), [1 => ASCII.ESC]),
         "STYLE-001 auto does not style a destination that is not a terminal");

      Assert
        (not T.Enabled (T.Resolve (T.Never, True, True, False)),
         "STYLE-001 never wins over a terminal");
      Assert
        (T.Enabled (T.Resolve (T.Always, True, False, True)),
         "STYLE-001 an explicit always wins over NO_COLOR");
      Assert
        (not T.Enabled (T.Resolve (T.Automatic, False, True, True)),
         "STYLE-001 NO_COLOR suppresses automatic styling");
      Assert
        (T.Style (T.Plain, "text", T.Error_Element) = "text",
         "STYLE-001 a plain policy returns the text unchanged");
   end Styling_Preserves_Information;

   --  STYLE-002: sed data is never styled, even when diagnostics are.

   procedure Sed_Data_Is_Never_Styled
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "good.txt", "kept" & LF);

      declare
         --  One operand fails and one succeeds, so the run styles a
         --  diagnostic and emits data in the same invocation.
         Result : constant Run_Result :=
           Run ([A ("--color=always"), A ("-n"), A ("--"), A ("p"),
                 A ("missing.txt"), A ("good.txt")],
                Files);
      begin
         Assert
           (Output (Result) = "kept" & LF,
            "STYLE-002 sed data is emitted unchanged");
         Assert
           (Contains (Errors (Result), [1 => ASCII.ESC]),
            "STYLE-002 the diagnostic is styled");
      end;
   end Sed_Data_Is_Never_Styled;

   --  LOCALE-001: messages come from the catalogue in every locale.

   procedure Messages_Are_Localized
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      English : constant Run_Result := Run ([A ("-x")], "", "en");
      Danish : constant Run_Result := Run ([A ("-x")], "", "da");
      Help_Danish : constant Run_Result := Run ([A ("--help")], "", "da");
   begin
      Assert
        (Contains (Errors (English), "unrecognized option"),
         "LOCALE-001 the primary locale renders its own text");
      Assert
        (Contains (Errors (Danish), "ukendt tilvalg"),
         "LOCALE-001 the alternate locale renders its own text");
      Assert
        (Errors (English) /= Errors (Danish),
         "LOCALE-001 the two locales differ");
      Assert
        (Contains (Errors (Danish), "'-x'"),
         "LOCALE-001 the option spelling is not translated");
      Assert
        (Contains (Output (Help_Danish), "Brug:"),
         "LOCALE-001 help is localized");
      Assert
        (Contains (Output (Help_Danish), "--version"),
         "LOCALE-001 option spellings in help are not translated");
   end Messages_Are_Localized;

   --  LOCALE-002: sed data is never localized.

   procedure Sed_Data_Is_Never_Localized
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      English : constant Run_Result :=
        Run ([A ("-n"), A ("--"), A ("=")], "a" & LF & "b" & LF, "en");
      Danish : constant Run_Result :=
        Run ([A ("-n"), A ("--"), A ("=")], "a" & LF & "b" & LF, "da");
   begin
      Assert
        (Output (English) = "1" & LF & "2" & LF,
         "LOCALE-002 line numbers are locale-neutral");
      Assert
        (Output (Danish) = Output (English),
         "LOCALE-002 the locale does not change sed output");
   end Sed_Data_Is_Never_Localized;

   --  FAIL-INPUT-001: a missing operand is recoverable; later operands run.

   procedure Recoverable_Input_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "one.txt", "a" & LF);
      Doubles.Add_File (Files, "two.txt", "b" & LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("p"),
                 A ("one.txt"), A ("missing.txt"), A ("two.txt")],
                Files);
      begin
         Assert
           (Output (Result) = "a" & LF & "b" & LF,
            "FAIL-INPUT-001 readable operands are still processed");
         Assert
           (Result.Exit_Status = 1,
            "FAIL-INPUT-001 the run reports a processing failure");
         Assert
           (Contains (Errors (Result), "missing.txt"),
            "FAIL-INPUT-001 the unreadable operand is named");
         Assert
           (Doubles.Open_Count (Files) = 0,
            "FAIL-INPUT-001 no handle is leaked");
      end;
   end Recoverable_Input_Failure;

   --  FAIL-INPUT-002: an operand that fails while being read is reported.

   procedure Injected_Read_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "broken.txt", "a" & LF & "b" & LF);
      Doubles.Fail_Read (Files, "broken.txt");
      Doubles.Add_File (Files, "good.txt", "c" & LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("p"), A ("broken.txt"), A ("good.txt")],
                Files);
      begin
         Assert
           (Result.Exit_Status = 1,
            "FAIL-INPUT-002 a read failure fails the run");
         Assert
           (Contains (Errors (Result), "broken.txt"),
            "FAIL-INPUT-002 the failing operand is named");
         Assert
           (Output (Result) = "c" & LF,
            "FAIL-INPUT-002 the following operand is still processed");
      end;
   end Injected_Read_Failure;

   --  FAIL-OUTPUT-001: a standard-output failure is fatal and reported once.

   procedure Injected_Output_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
      Input : Doubles.Memory_Input;
      Output_Stream : Doubles.Memory_Output;
      Error_Stream : Doubles.Memory_Output;
      Arguments : Sed.Command_Line.Arguments.Fixed_List;
      Outcome : Sed.Status.Outcome;
   begin
      Sed.Command_Line.Arguments.Append (Arguments, "--");
      Sed.Command_Line.Arguments.Append (Arguments, "p");
      Doubles.Set_Text (Input, "a" & LF & "b" & LF & "c" & LF);

      --  Accept nothing at all, so the very first write fails.
      Doubles.Fail_Writes_After (Output_Stream, 0);

      Outcome :=
        Sed.Application.Execute
          (Arguments => Arguments,
           Standard_In => Input,
           Standard_Out => Output_Stream,
           Standard_Err => Error_Stream,
           Filesystem => Files,
           Context => Environment);

      Assert
        (Outcome = Sed.Status.Processing_Failure,
         "FAIL-OUTPUT-001 an output failure fails the run");
      Assert
        (Contains (Doubles.Text (Error_Stream), "standard output"),
         "FAIL-OUTPUT-001 the failure is reported");

      declare
         Count : Natural := 0;
         Text : constant String := Doubles.Text (Error_Stream);
      begin
         for Index in Text'Range loop
            if Text (Index) = LF then
               Count := Count + 1;
            end if;
         end loop;

         Assert
           (Count = 1,
            "FAIL-OUTPUT-001 a broken stream reports one line, not one per"
            & " record; got [" & Text & "]");
      end;
   end Injected_Output_Failure;

   --  FAIL-OUTPUT-002: a w destination that cannot be created is fatal, and
   --  it is fatal before any input is processed.

   procedure Injected_Write_Target_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Fail_Create (Files, "out.txt");

      declare
         Result : constant Run_Result :=
           Run ([A ("--"), A ("w out.txt")], Files, "a" & LF);
      begin
         Assert
           (Result.Exit_Status = 1,
            "FAIL-OUTPUT-002 an uncreatable destination fails the run");
         Assert
           (Output (Result) = "",
            "FAIL-OUTPUT-002 no input is processed");
         Assert
           (Contains (Errors (Result), "out.txt"),
            "FAIL-OUTPUT-002 the destination is named");
      end;
   end Injected_Write_Target_Failure;

   --  FAIL-OUTPUT-003: a w destination that fails while being written is
   --  reported without any claim that the file was rolled back.

   procedure Injected_Write_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "out.txt", "");
      Doubles.Fail_Write (Files, "out.txt");

      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("w out.txt")], Files, "a" & LF);
      begin
         Assert
           (Result.Exit_Status = 1,
            "FAIL-OUTPUT-003 a write failure fails the run");
         Assert
           (Contains (Errors (Result), "out.txt"),
            "FAIL-OUTPUT-003 the destination is named");
      end;
   end Injected_Write_Failure;

   --  DIAG-CODE-001: the diagnostic codes a script can provoke directly.

   procedure Script_Diagnostics_Are_Reported
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Undefined : constant Run_Result :=
        Run ([A ("--"), A ("b nosuch")], "x" & LF);
      Duplicate : constant Run_Result :=
        Run ([A ("--"), A (":x" & LF & ":x")], "x" & LF);
   begin
      Assert
        (Contains (Errors (Undefined), "undefined label"),
         "DIAG-CODE-001 an undefined branch target is reported");
      Assert
        (Undefined.Exit_Status = 1,
         "DIAG-CODE-001 an undefined label fails the run");

      Assert
        (Contains (Errors (Duplicate), "duplicate label"),
         "DIAG-CODE-001 a duplicate label is reported");
      Assert
        (Duplicate.Exit_Status = 1,
         "DIAG-CODE-001 a duplicate label fails the run");
   end Script_Diagnostics_Are_Reported;

   --  DIAG-CODE-002: a script file that opens but cannot be read through is a
   --  different fault from one that cannot be opened at all.

   procedure Script_File_Read_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "rules.sed", "p" & LF);
      Doubles.Fail_Read (Files, "rules.sed");

      declare
         Result : constant Run_Result :=
           Run ([A ("-f"), A ("rules.sed")], Files, "x" & LF);
      begin
         Assert
           (Result.Exit_Status = 1,
            "DIAG-CODE-002 a script read failure fails the run");
         Assert
           (Contains (Errors (Result), "error reading script file"),
            "DIAG-CODE-002 the read failure is distinguished from an open failure");
         Assert
           (Output (Result) = "",
            "DIAG-CODE-002 no input is processed");
      end;
   end Script_File_Read_Failure;

   --  DIAG-CODE-003: an r file that opens but faults while being read.
   --
   --  POSIX gives r no error status, so this is a warning that leaves the
   --  exit status alone while still telling the user the output is short.

   procedure Resource_Read_Failure_Warns
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "extra.txt", "X" & LF);
      Doubles.Fail_Read (Files, "extra.txt");

      declare
         Result : constant Run_Result :=
           Run ([A ("--"), A ("r extra.txt")], Files, "a" & LF);
      begin
         Assert
           (Output (Result) = "a" & LF,
            "DIAG-CODE-003 the cycle still produces its own output");
         Assert
           (Contains (Errors (Result), "r command"),
            "DIAG-CODE-003 the read fault is reported");
         Assert
           (Result.Exit_Status = 0,
            "DIAG-CODE-003 a warning leaves the exit status alone");
      end;
   end Resource_Read_Failure_Warns;

   --  DIAG-CODE-004: an engine bound reports as resource exhaustion rather
   --  than as a crash or a truncated result.

   procedure Engine_Limit_Is_Reported
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      --  Long enough that a backreferenced match exceeds the engine's
      --  bounded backtracking depth.
      Long_Line : constant String := [1 .. 60_000 => 'a'] & LF;
      Result : constant Run_Result :=
        Run ([A ("--"), A ("s/\(a*\)\1/X/")], Long_Line);
   begin
      Assert
        (Result.Exit_Status = 1,
         "DIAG-CODE-004 exceeding an engine bound fails the run");
      Assert
        (Contains (Errors (Result), "resource limit exceeded"),
         "DIAG-CODE-004 the bound is reported as resource exhaustion");
   end Engine_Limit_Is_Reported;

   --  DIAG-MAPPING-001: every engine condition maps to the intended code.
   --
   --  Two codes cover conditions the resolved engine does not currently
   --  produce: Unsupported_Command is its internal guard for a command with
   --  no compiler mapping, and Program_Not_Executable cannot occur behind the
   --  precondition on execution. They are kept because an engine that did
   --  report them must not have the fault silently reclassified as a user
   --  script error, and the mapping is tested here directly rather than left
   --  to a case that cannot be written.

   procedure Engine_Codes_Map_As_Intended
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      use type Sedlib.Diagnostics.Diagnostic_Code;
   begin
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Unsupported_Command) =
           D.Missing_Library_Capability,
         "DIAG-MAPPING-001 an unimplemented engine command is a capability gap");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Resource_Provider_Missing) =
           D.Missing_Library_Capability,
         "DIAG-MAPPING-001 a missing resource provider is a capability gap");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Program_Not_Executable) =
           D.Execution_Failed,
         "DIAG-MAPPING-001 an unexecutable program is an execution failure");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Cancelled) = D.Execution_Failed,
         "DIAG-MAPPING-001 cancellation is an execution failure");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Invalid_Expression) =
           D.Invalid_Regular_Expression,
         "DIAG-MAPPING-001 an invalid expression is a regexp failure");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Undefined_Label) =
           D.Undefined_Label,
         "DIAG-MAPPING-001 an undefined label keeps its own code");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Unsupported_Extension) =
           D.Script_Syntax_Error,
         "DIAG-MAPPING-001 a rejected extension is a script error, not a gap");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Unknown_Command) =
           D.Script_Syntax_Error,
         "DIAG-MAPPING-001 an unknown command is a script error");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Internal_Invariant_Failure) =
           D.Internal_Error,
         "DIAG-MAPPING-001 an engine invariant failure is an internal error");
      Assert
        (Sed.Engine.Code_Of (Sedlib.Diagnostics.Regexp_Match_Limit_Exceeded) =
           D.Resource_Exhausted,
         "DIAG-MAPPING-001 an engine bound is resource exhaustion");
   end Engine_Codes_Map_As_Intended;

   --  TOOL-REGISTRY-001: the traceability registries are internally sound.
   --
   --  Whether the test identifiers they cite actually exist is checked by
   --  "sed_tools verify", which can read the whole test tree; what is checked
   --  here is that no entry is empty or malformed in the first place.

   procedure Registries_Are_Consistent
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      use type Sed_Registries.Text.Bounded_String;

      Requirements : constant Sed_Registries.Requirement_Array :=
        Sed_Registries.Requirements;
      Commands : constant Sed_Registries.Command_Array :=
        Sed_Registries.Commands;
   begin
      Assert (Requirements'Length > 0, "TOOL-REGISTRY-001 requirements exist");

      for Item of Requirements loop
         declare
            Id : constant String := Sed_Registries.Text.To_String (Item.Id);
         begin
            Assert
              (Contains (Id, "SED-"),
               "TOOL-REGISTRY-001 " & Id & " uses the project prefix");
            Assert
              (Sed_Registries.Text.Length (Item.Summary) > 0,
               "TOOL-REGISTRY-001 " & Id & " has a summary");
            Assert
              (Sed_Registries.Text.Length (Item.Owner) > 0,
               "TOOL-REGISTRY-001 " & Id & " names an owning package");
            Assert
              (Sed_Registries.Text.Length (Item.Tests) > 0,
               "TOOL-REGISTRY-001 " & Id & " cites at least one test");
         end;
      end loop;

      --  Every requirement identifier is distinct, so two claims cannot share
      --  one line of evidence by accident.
      for Left in Requirements'Range loop
         for Right in Left + 1 .. Requirements'Last loop
            Assert
              (Requirements (Left).Id /= Requirements (Right).Id,
               "TOOL-REGISTRY-001 requirement identifiers are unique");
         end loop;
      end loop;

      for Item of Commands loop
         Assert
           (Sed_Registries.Text.Length (Item.Tests) > 0,
            "TOOL-REGISTRY-001 command " & Item.Symbol & " cites a test");
         Assert
           (Item.Max_Addresses <= 2,
            "TOOL-REGISTRY-001 command " & Item.Symbol
            & " accepts at most two addresses");
      end loop;

      --  Every diagnostic code carries coverage, and a code that cannot be
      --  provoked through the command line has to say why.
      for Code in Sed.Diagnostics.Diagnostic_Code loop
         declare
            Row : constant Sed_Registries.Coverage :=
              Sed_Registries.Diagnostic_Coverage (Code);
            Label : constant String :=
              Sed.Diagnostics.Diagnostic_Code'Image (Code);
         begin
            Assert
              (Sed_Registries.Text.Length (Row.Tests) > 0,
               "TOOL-REGISTRY-001 " & Label & " cites at least one test");
         end;
      end loop;
   end Registries_Are_Consistent;

   overriding procedure Register_Tests (Test : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (Test, Status_Is_Monotonic'Access, "STATUS-001 status monotonicity");
      Register_Routine
        (Test, Registry_Is_Complete'Access,
         "DIAG-REGISTRY-001 diagnostic registry completeness");
      Register_Routine
        (Test, Diagnostic_Schema_Is_Enforced'Access,
         "DIAG-SCHEMA-001 parameter schema");
      Register_Routine
        (Test, Quoting_Neutralizes_Untrusted_Values'Access,
         "DIAG-ESCAPE-001 quoting");
      Register_Routine
        (Test, Rendered_Diagnostics_Are_Escaped'Access,
         "DIAG-ESCAPE-002 rendered diagnostics are escaped");
      Register_Routine
        (Test, Styling_Preserves_Information'Access,
         "STYLE-001 styling preserves information");
      Register_Routine
        (Test, Sed_Data_Is_Never_Styled'Access,
         "STYLE-002 sed data is never styled");
      Register_Routine
        (Test, Messages_Are_Localized'Access,
         "LOCALE-001 messages are localized");
      Register_Routine
        (Test, Sed_Data_Is_Never_Localized'Access,
         "LOCALE-002 sed data is never localized");
      Register_Routine
        (Test, Recoverable_Input_Failure'Access,
         "FAIL-INPUT-001 recoverable input failure");
      Register_Routine
        (Test, Injected_Read_Failure'Access,
         "FAIL-INPUT-002 injected read failure");
      Register_Routine
        (Test, Injected_Output_Failure'Access,
         "FAIL-OUTPUT-001 injected standard-output failure");
      Register_Routine
        (Test, Injected_Write_Target_Failure'Access,
         "FAIL-OUTPUT-002 injected w creation failure");
      Register_Routine
        (Test, Injected_Write_Failure'Access,
         "FAIL-OUTPUT-003 injected w write failure");
      Register_Routine
        (Test, Script_Diagnostics_Are_Reported'Access,
         "DIAG-CODE-001 script diagnostics");
      Register_Routine
        (Test, Script_File_Read_Failure'Access,
         "DIAG-CODE-002 script file read failure");
      Register_Routine
        (Test, Resource_Read_Failure_Warns'Access,
         "DIAG-CODE-003 r file read failure warns");
      Register_Routine
        (Test, Engine_Limit_Is_Reported'Access,
         "DIAG-CODE-004 engine limit is reported");
      Register_Routine
        (Test, Engine_Codes_Map_As_Intended'Access,
         "DIAG-MAPPING-001 engine code mapping");
      Register_Routine
        (Test, Registries_Are_Consistent'Access,
         "TOOL-REGISTRY-001 registry consistency");
   end Register_Tests;

end Sed_Test_Suite.Robustness;

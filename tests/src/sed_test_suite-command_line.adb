with AUnit.Assertions;
with Sed.Command_Line.Arguments;
with Sed.Command_Line.Options;
with Sed.Command_Line.Validation;
with Sed.Diagnostics;
with Sed.Status;
with Sed_Test_Suite.Support;

package body Sed_Test_Suite.Command_Line is

   use AUnit.Assertions;
   use Sed_Test_Suite.Support;

   package CL renames Sed.Command_Line;
   package D renames Sed.Diagnostics;

   use type CL.Color_Mode;
   use type CL.Invocation_Mode;
   use type CL.Operand_Kind;
   use type CL.Script_Source_Kind;
   use type D.Diagnostic_Code;
   use type Sed.Status.Exit_Status;
   use type Sed.Status.Outcome;

   overriding function Name (Test : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (Test);
   begin
      return AUnit.Format ("sed command line");
   end Name;

   --  Parse an argument list structurally, without running anything.
   function Parse (Arguments : Argument_Array) return CL.Parse_Result;

   -----------
   -- Parse --
   -----------

   function Parse (Arguments : Argument_Array) return CL.Parse_Result is
      List : CL.Arguments.Fixed_List;
   begin
      for Item of Arguments loop
         CL.Arguments.Append (List, U.To_String (Item));
      end loop;

      return CL.Validation.Validate (CL.Options.Parse (List));
   end Parse;

   --  CLI-VALID-001: a positional script with no options.

   procedure Valid_Positional_Script
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result := Parse ([A ("p")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-001 parses");

      declare
         Item : constant CL.Invocation := CL.Value (Result);
      begin
         Assert (CL.Mode (Item) = CL.Run_Mode, "CLI-VALID-001 run mode");
         Assert (CL.Script_Count (Item) = 1, "CLI-VALID-001 one script");
         Assert
           (CL.Script (Item, 1).Kind = CL.Inline_Expression,
            "CLI-VALID-001 script is inline");
         Assert
           (CL.Script (Item, 1).Positional,
            "CLI-VALID-001 script is positional");
         Assert
           (U.To_String (CL.Script (Item, 1).Value) = "p",
            "CLI-VALID-001 script text");
         Assert (CL.Operand_Count (Item) = 0, "CLI-VALID-001 no operands");
         Assert
           (not CL.Suppress_Automatic_Output (Item),
            "CLI-VALID-001 automatic output stays on");
      end;
   end Valid_Positional_Script;

   --  CLI-VALID-002: -n before a positional script.

   procedure Valid_Quiet_Positional
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result := Parse ([A ("-n"), A ("p")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-002 parses");
      Assert
        (CL.Suppress_Automatic_Output (CL.Value (Result)),
         "CLI-VALID-002 suppresses automatic output");
      Assert
        (CL.Script_Count (CL.Value (Result)) = 1,
         "CLI-VALID-002 one script");
   end Valid_Quiet_Positional;

   --  CLI-VALID-003: once -e is present every operand is an input file.

   procedure Valid_Expression_Then_Operands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result :=
        Parse ([A ("-e"), A ("s/a/b/"), A ("file")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-003 parses");

      declare
         Item : constant CL.Invocation := CL.Value (Result);
      begin
         Assert (CL.Script_Count (Item) = 1, "CLI-VALID-003 one script");
         Assert
           (not CL.Script (Item, 1).Positional,
            "CLI-VALID-003 script came from an option");
         Assert (CL.Operand_Count (Item) = 1, "CLI-VALID-003 one operand");
         Assert
           (U.To_String (CL.Operand (Item, 1).Name) = "file",
            "CLI-VALID-003 operand is the file");
         Assert
           (CL.Operand (Item, 1).Kind = CL.Named_File,
            "CLI-VALID-003 operand is a named file");
      end;
   end Valid_Expression_Then_Operands;

   --  CLI-VALID-004: an argument attached to a short option.

   procedure Valid_Attached_Expression
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result := Parse ([A ("-ep")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-004 parses");
      Assert
        (U.To_String (CL.Script (CL.Value (Result), 1).Value) = "p",
         "CLI-VALID-004 attached argument is the script");
   end Valid_Attached_Expression;

   --  CLI-VALID-005: a short-option cluster ending in one that takes an
   --  argument.

   procedure Valid_Clustered_Options
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result := Parse ([A ("-ne"), A ("p")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-005 parses");

      declare
         Item : constant CL.Invocation := CL.Value (Result);
      begin
         Assert
           (CL.Suppress_Automatic_Output (Item),
            "CLI-VALID-005 cluster applies -n");
         Assert
           (U.To_String (CL.Script (Item, 1).Value) = "p",
            "CLI-VALID-005 cluster takes the next word as the argument");
      end;
   end Valid_Clustered_Options;

   --  CLI-VALID-006: repeated -n is harmless.

   procedure Valid_Repeated_Quiet
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result :=
        Parse ([A ("-n"), A ("-n"), A ("p")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-006 parses");
      Assert
        (CL.Suppress_Automatic_Output (CL.Value (Result)),
         "CLI-VALID-006 repeated -n equals one");
   end Valid_Repeated_Quiet;

   --  CLI-VALID-007: -- ends option processing so a script may start with -.

   procedure Valid_Terminator
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result := Parse ([A ("--"), A ("-script")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-007 parses");
      Assert
        (U.To_String (CL.Script (CL.Value (Result), 1).Value) = "-script",
         "CLI-VALID-007 the operand after -- is the script");
   end Valid_Terminator;

   --  CLI-VALID-008: a bare - names standard input, never an option.

   procedure Valid_Standard_Input_Operand
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result := Parse ([A ("p"), A ("-")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-008 parses");
      Assert
        (CL.Operand (CL.Value (Result), 1).Kind = CL.Standard_Input,
         "CLI-VALID-008 a bare hyphen is standard input");
   end Valid_Standard_Input_Operand;

   --  CLI-VALID-009: --color is recognized and recorded.

   procedure Valid_Color_Option
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant CL.Parse_Result :=
        Parse ([A ("--color=never"), A ("p")]);
   begin
      Assert (CL.Succeeded (Result), "CLI-VALID-009 parses");
      Assert
        (CL.Color (CL.Value (Result)) = CL.Color_Never,
         "CLI-VALID-009 colour mode is never");
      Assert
        (CL.Color_Was_Explicit (CL.Value (Result)),
         "CLI-VALID-009 colour was explicit");
   end Valid_Color_Option;

   --  CLI-VALID-010: administrative modes are recognized and load nothing.

   procedure Valid_Administrative_Modes
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Help : constant CL.Parse_Result := Parse ([A ("--help")]);
      Version : constant CL.Parse_Result := Parse ([A ("--version")]);
   begin
      Assert (CL.Succeeded (Help), "CLI-VALID-010 help parses");
      Assert
        (CL.Mode (CL.Value (Help)) = CL.Help_Mode,
         "CLI-VALID-010 help mode");
      Assert
        (CL.Script_Count (CL.Value (Help)) = 0,
         "CLI-VALID-010 help loads no script");
      Assert (CL.Succeeded (Version), "CLI-VALID-010 version parses");
      Assert
        (CL.Mode (CL.Value (Version)) = CL.Version_Mode,
         "CLI-VALID-010 version mode");
   end Valid_Administrative_Modes;

   --  CLI-ERROR-001 .. 007: malformed invocations.

   procedure Invalid_Invocations
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);

      --  Assert that an argument list is rejected with a given code.
      procedure Rejects
        (Arguments : Argument_Array;
         Code : D.Diagnostic_Code;
         Label : String);

      -------------
      -- Rejects --
      -------------

      procedure Rejects
        (Arguments : Argument_Array;
         Code : D.Diagnostic_Code;
         Label : String)
      is
         Result : constant CL.Parse_Result := Parse (Arguments);
      begin
         Assert (not CL.Succeeded (Result), Label & " is rejected");
         Assert
           (D.Code (CL.Failure (Result)) = Code,
            Label & " reports the expected code");
         Assert
           (D.Status_Effect (CL.Failure (Result)) =
              Sed.Status.Invocation_Failure,
            Label & " is an invocation failure");
         Assert
           (D.Schema_Satisfied (CL.Failure (Result)),
            Label & " satisfies its parameter schema");
      end Rejects;

   begin
      Rejects (No_Arguments, D.Missing_Script, "CLI-ERROR-001 sed");
      Rejects ([A ("-e")], D.Missing_Option_Argument, "CLI-ERROR-002 sed -e");
      Rejects ([A ("-f")], D.Missing_Option_Argument, "CLI-ERROR-003 sed -f");
      Rejects ([A ("-x")], D.Unknown_Option, "CLI-ERROR-004 sed -x");
      Rejects
        ([A ("--unknown")], D.Unknown_Option, "CLI-ERROR-005 sed --unknown");
      Rejects
        ([A ("--color")],
         D.Missing_Option_Argument,
         "CLI-ERROR-006 sed --color");
      Rejects
        ([A ("--color=invalid")],
         D.Invalid_Option_Argument,
         "CLI-ERROR-007 sed --color=invalid");
   end Invalid_Invocations;

   --  CLI-ERROR-008: GNU options this release does not implement are unknown
   --  options rather than silent aliases.

   procedure Rejects_Unimplemented_Gnu_Options
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Spellings : constant array (1 .. 8) of U.Unbounded_String :=
        [A ("-i"), A ("-E"), A ("-r"), A ("-z"), A ("-s"), A ("-u"),
         A ("--posix"), A ("--regexp-extended")];
   begin
      for Spelling of Spellings loop
         declare
            Result : constant CL.Parse_Result :=
              Parse ([Spelling, A ("p")]);
         begin
            Assert
              (not CL.Succeeded (Result),
               "CLI-ERROR-008 " & U.To_String (Spelling) & " is rejected");
            Assert
              (D.Code (CL.Failure (Result)) = D.Unknown_Option,
               "CLI-ERROR-008 " & U.To_String (Spelling)
               & " is an unknown option");
         end;
      end loop;
   end Rejects_Unimplemented_Gnu_Options;

   --  CLI-STATUS-001: an invalid invocation exits 2, writes only to standard
   --  error, and offers the localized help hint.

   procedure Invocation_Failure_Reaches_Process
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant Run_Result := Run ([A ("-x")]);
   begin
      Assert (Result.Exit_Status = 2, "CLI-STATUS-001 exits with status 2");
      Assert (Output (Result) = "", "CLI-STATUS-001 standard output is empty");
      Assert
        (Contains (Errors (Result), "unrecognized option"),
         "CLI-STATUS-001 names the failure");
      Assert
        (Contains (Errors (Result), "'-x'"),
         "CLI-STATUS-001 quotes the offending option");
      Assert
        (Contains (Errors (Result), "--help"),
         "CLI-STATUS-001 offers the help hint");
   end Invocation_Failure_Reaches_Process;

   --  CLI-STATUS-002: help and version succeed and write to standard output.

   procedure Administrative_Output_Reaches_Process
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Help : constant Run_Result := Run ([A ("--help")]);
      Version : constant Run_Result := Run ([A ("--version")]);
   begin
      Assert (Help.Exit_Status = 0, "CLI-STATUS-002 help exits 0");
      Assert (Errors (Help) = "", "CLI-STATUS-002 help writes no diagnostics");
      Assert
        (Contains (Output (Help), "-n"),
         "CLI-STATUS-002 help lists the -n option");
      Assert
        (Contains (Output (Help), "--version"),
         "CLI-STATUS-002 help lists every registered option");
      Assert (Version.Exit_Status = 0, "CLI-STATUS-002 version exits 0");
      Assert
        (Contains (Output (Version), "sedlib"),
         "CLI-STATUS-002 version names the engine");
   end Administrative_Output_Reaches_Process;

   overriding procedure Register_Tests (Test : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (Test, Valid_Positional_Script'Access,
         "CLI-VALID-001 positional script");
      Register_Routine
        (Test, Valid_Quiet_Positional'Access,
         "CLI-VALID-002 quiet positional script");
      Register_Routine
        (Test, Valid_Expression_Then_Operands'Access,
         "CLI-VALID-003 expression then operands");
      Register_Routine
        (Test, Valid_Attached_Expression'Access,
         "CLI-VALID-004 attached option argument");
      Register_Routine
        (Test, Valid_Clustered_Options'Access,
         "CLI-VALID-005 clustered short options");
      Register_Routine
        (Test, Valid_Repeated_Quiet'Access,
         "CLI-VALID-006 repeated -n");
      Register_Routine
        (Test, Valid_Terminator'Access,
         "CLI-VALID-007 option terminator");
      Register_Routine
        (Test, Valid_Standard_Input_Operand'Access,
         "CLI-VALID-008 standard input operand");
      Register_Routine
        (Test, Valid_Color_Option'Access,
         "CLI-VALID-009 colour option");
      Register_Routine
        (Test, Valid_Administrative_Modes'Access,
         "CLI-VALID-010 administrative modes");
      Register_Routine
        (Test, Invalid_Invocations'Access,
         "CLI-ERROR-001..007 malformed invocations");
      Register_Routine
        (Test, Rejects_Unimplemented_Gnu_Options'Access,
         "CLI-ERROR-008 unimplemented GNU options are unknown");
      Register_Routine
        (Test, Invocation_Failure_Reaches_Process'Access,
         "CLI-STATUS-001 invocation failure status and streams");
      Register_Routine
        (Test, Administrative_Output_Reaches_Process'Access,
         "CLI-STATUS-002 help and version output");
   end Register_Tests;

end Sed_Test_Suite.Command_Line;

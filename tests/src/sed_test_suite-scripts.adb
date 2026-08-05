with AUnit.Assertions;
with Sed.Diagnostics;
with Sed.Scripts;
with Sed.Scripts.Compilation;
with Sed.Status;
with Sed_Test_Suite.Doubles;
with Sed_Test_Suite.Support;

package body Sed_Test_Suite.Scripts is

   use AUnit.Assertions;
   use Sed_Test_Suite.Support;

   package D renames Sed.Diagnostics;
   package S renames Sed.Scripts;

   use type D.Diagnostic_Code;
   use type D.Location_Kind;
   use type Sed.Status.Exit_Status;
   use type Sed.Line_Count;

   overriding function Name (Test : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (Test);
   begin
      return AUnit.Format ("sed script sources");
   end Name;

   --  SCRIPT-ORDER-001: -f and -e sources keep exact command-line order.

   procedure Sources_Keep_Command_Line_Order
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "first.sed", "s/x/1/" & ASCII.LF);
      Doubles.Add_File (Files, "last.sed", "s/2/3/" & ASCII.LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-f"), A ("first.sed"),
                 A ("-e"), A ("s/1/2/"),
                 A ("-f"), A ("last.sed"),
                 A ("-e"), A ("s/3/z/")],
                Files,
                "x" & ASCII.LF);
      begin
         --  Applied in order the substitutions turn x into 1, 2, 3 and then z.
         --  Any other ordering produces a different byte.
         Assert
           (Output (Result) = "z" & ASCII.LF,
            "SCRIPT-ORDER-001 sources apply in command-line order, got ["
            & Output (Result) & "]");
         Assert (Result.Exit_Status = 0, "SCRIPT-ORDER-001 succeeds");
      end;
   end Sources_Keep_Command_Line_Order;

   --  SCRIPT-BOUNDARY-001: separate -e sources never merge into one command.

   procedure Sources_Do_Not_Merge
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant Run_Result :=
        Run ([A ("-n"), A ("-e"), A ("s/a/b/"), A ("-e"), A ("p")],
             "a" & ASCII.LF);
   begin
      --  Merged, these would read as "s/a/b/p" and print through the flag.
      --  Kept apart, the p is its own command and prints once.
      Assert
        (Output (Result) = "b" & ASCII.LF,
         "SCRIPT-BOUNDARY-001 adjacent sources stay separate commands");
   end Sources_Do_Not_Merge;

   --  SCRIPT-BOUNDARY-002: a text command may span a source boundary, which
   --  is exactly what the newline join between sources is for.

   procedure Text_Command_Spans_Sources
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant Run_Result :=
        Run ([A ("-e"), A ("a\"), A ("-e"), A ("appended")], "x" & ASCII.LF);
   begin
      Assert
        (Output (Result) = "x" & ASCII.LF & "appended" & ASCII.LF,
         "SCRIPT-BOUNDARY-002 a text command continues into the next source");
   end Text_Command_Spans_Sources;

   --  SCRIPT-BOUNDARY-003: an empty inline script and an empty script file are
   --  both valid and contribute nothing.

   procedure Empty_Sources_Are_Valid
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "empty.sed", "");

      declare
         Result : constant Run_Result :=
           Run ([A ("-e"), A (""), A ("-f"), A ("empty.sed"), A ("-e"), A ("p")],
                Files,
                "x" & ASCII.LF);
      begin
         Assert
           (Output (Result) = "x" & ASCII.LF & "x" & ASCII.LF,
            "SCRIPT-BOUNDARY-003 empty sources are valid and inert");
      end;
   end Empty_Sources_Are_Valid;

   --  SCRIPT-MAP-001: the source map places an offset in the right unit, at
   --  the right line and column inside that unit.

   procedure Source_Map_Locates_Units
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Set : S.Source_Set := S.Empty_Set;
   begin
      S.Append (Set, S.Inline_Expression, "p", Occurrence => 1, Ordinal => 1);
      S.Append
        (Set, S.Script_File, "d" & ASCII.LF & "  q",
         Path => "rules.sed", Occurrence => 1, Ordinal => 2);
      S.Append (Set, S.Inline_Expression, "x", Occurrence => 2, Ordinal => 3);

      Assert (S.Count (Set) = 3, "SCRIPT-MAP-001 three units");
      Assert
        (S.Combined_Text (Set) =
           "p" & ASCII.LF & "d" & ASCII.LF & "  q" & ASCII.LF & "x" & ASCII.LF,
         "SCRIPT-MAP-001 units are joined by newlines");

      declare
         First : constant D.Source_Location := S.Locate (Set, 0);
         In_File : constant D.Source_Location := S.Locate (Set, 2);
         Second_Line : constant D.Source_Location := S.Locate (Set, 6);
         Last : constant D.Source_Location := S.Locate (Set, 8);
      begin
         Assert
           (First.Kind = D.Expression_Location and then First.Occurrence = 1,
            "SCRIPT-MAP-001 offset 0 is the first expression");
         Assert
           (First.Line = 1 and then First.Column = 1,
            "SCRIPT-MAP-001 first expression line and column");

         Assert
           (In_File.Kind = D.Path_Location,
            "SCRIPT-MAP-001 the file unit is a path location");
         Assert
           (U.To_String (In_File.Path) = "rules.sed",
            "SCRIPT-MAP-001 the path is the one the user wrote");
         Assert
           (In_File.Line = 1 and then In_File.Column = 1,
            "SCRIPT-MAP-001 line and column are local to the file");

         Assert
           (Second_Line.Kind = D.Path_Location
              and then Second_Line.Line = 2
              and then Second_Line.Column = 3,
            "SCRIPT-MAP-001 a later line maps to the file line and column");

         Assert
           (Last.Kind = D.Expression_Location and then Last.Occurrence = 2,
            "SCRIPT-MAP-001 the last unit is the second expression");
      end;
   end Source_Map_Locates_Units;

   --  SCRIPT-DIAG-001: a compile failure is reported against the source unit
   --  the user wrote, not against the concatenation.

   procedure Compile_Failure_Names_Source_Unit
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Result : constant Run_Result :=
        Run ([A ("-e"), A ("p"), A ("-e"), A ("ZZZ")], "x" & ASCII.LF);
   begin
      Assert (Result.Exit_Status = 1, "SCRIPT-DIAG-001 exits with status 1");
      Assert
        (Contains (Errors (Result), "command line expression 2"),
         "SCRIPT-DIAG-001 names the second expression");
      Assert
        (Output (Result) = "",
         "SCRIPT-DIAG-001 nothing reaches standard output");
   end Compile_Failure_Names_Source_Unit;

   --  SCRIPT-DIAG-002: a failure inside a -f file names the path, and the
   --  line and column within that file.

   procedure Compile_Failure_Names_Script_File
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "rules.sed", "p" & ASCII.LF & "s/[/x/" & ASCII.LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-f"), A ("rules.sed")], Files, "x" & ASCII.LF);
      begin
         Assert (Result.Exit_Status = 1, "SCRIPT-DIAG-002 exits with status 1");
         Assert
           (Contains (Errors (Result), "rules.sed:2:3"),
            "SCRIPT-DIAG-002 reports the file line and column");
         Assert
           (Contains (Errors (Result), "invalid regular expression"),
            "SCRIPT-DIAG-002 classifies the failure");
      end;
   end Compile_Failure_Names_Script_File;

   --  SCRIPT-LOAD-001: an unreadable -f file is fatal before any input
   --  operand is opened.

   procedure Unreadable_Script_File_Is_Fatal
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "input.txt", "x" & ASCII.LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-f"), A ("missing.sed"), A ("input.txt")], Files);
      begin
         Assert (Result.Exit_Status = 1, "SCRIPT-LOAD-001 exits with status 1");
         Assert
           (Output (Result) = "",
            "SCRIPT-LOAD-001 no input is processed");
         Assert
           (Contains (Errors (Result), "missing.sed"),
            "SCRIPT-LOAD-001 names the script file");
         Assert
           (Doubles.Open_Count (Files) = 0,
            "SCRIPT-LOAD-001 leaves no file open");
      end;
   end Unreadable_Script_File_Is_Fatal;

   --  SCRIPT-WRITE-001: compilation completes before a w destination is
   --  created, so a script that fails to compile never truncates a file.

   procedure Compile_Failure_Leaves_Write_Target_Untouched
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "out.txt", "existing" & ASCII.LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-e"), A ("w out.txt"), A ("-e"), A ("ZZZ")],
                Files,
                "x" & ASCII.LF);
      begin
         Assert (Result.Exit_Status = 1, "SCRIPT-WRITE-001 exits with status 1");
         Assert
           (Doubles.Content (Files, "out.txt") = "existing" & ASCII.LF,
            "SCRIPT-WRITE-001 the write target is untouched");
         Assert
           (Doubles.Create_Count (Files, "out.txt") = 0,
            "SCRIPT-WRITE-001 the write target was never created");
      end;
   end Compile_Failure_Leaves_Write_Target_Untouched;

   --  SCRIPT-WRITE-002: a destination named by several commands is created
   --  exactly once, so earlier lines are not lost.

   procedure Write_Target_Is_Created_Once
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("-e"), A ("/a/w out.txt"), A ("-e"), A ("/b/w out.txt")],
                Files,
                "a" & ASCII.LF & "b" & ASCII.LF);
      begin
         Assert (Result.Exit_Status = 0, "SCRIPT-WRITE-002 succeeds");
         Assert
           (Doubles.Create_Count (Files, "out.txt") = 1,
            "SCRIPT-WRITE-002 the destination is created exactly once");
         Assert
           (Doubles.Content (Files, "out.txt") = "a" & ASCII.LF & "b" & ASCII.LF,
            "SCRIPT-WRITE-002 both commands append to the same file");
      end;
   end Write_Target_Is_Created_Once;

   --  SCRIPT-WRITE-003: the compiled program reports its write destinations,
   --  which is what lets them be created before execution.

   procedure Compiled_Program_Reports_Destinations
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Set : S.Source_Set := S.Empty_Set;
      Program : S.Compilation.Compiled_Program;
      Diagnostics : D.Diagnostic_List;
      Success : Boolean;
   begin
      S.Append
        (Set, S.Inline_Expression,
         "w first.txt" & ASCII.LF & "s/a/b/w second.txt" & ASCII.LF
         & "w first.txt");

      S.Compilation.Compile (Set, Program, Diagnostics, Success);

      Assert (Success, "SCRIPT-WRITE-003 the script compiles");
      Assert
        (S.Compilation.Write_Destination_Count (Program) = 2,
         "SCRIPT-WRITE-003 repeated destinations are reported once");
      Assert
        (S.Compilation.Write_Destination (Program, 1) = "first.txt",
         "SCRIPT-WRITE-003 destinations keep first-appearance order");
      Assert
        (S.Compilation.Write_Destination (Program, 2) = "second.txt",
         "SCRIPT-WRITE-003 a substitution write destination is reported");
   end Compiled_Program_Reports_Destinations;

   overriding procedure Register_Tests (Test : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (Test, Sources_Keep_Command_Line_Order'Access,
         "SCRIPT-ORDER-001 sources keep command-line order");
      Register_Routine
        (Test, Sources_Do_Not_Merge'Access,
         "SCRIPT-BOUNDARY-001 sources do not merge");
      Register_Routine
        (Test, Text_Command_Spans_Sources'Access,
         "SCRIPT-BOUNDARY-002 text command spans sources");
      Register_Routine
        (Test, Empty_Sources_Are_Valid'Access,
         "SCRIPT-BOUNDARY-003 empty sources are valid");
      Register_Routine
        (Test, Source_Map_Locates_Units'Access,
         "SCRIPT-MAP-001 source map locates units");
      Register_Routine
        (Test, Compile_Failure_Names_Source_Unit'Access,
         "SCRIPT-DIAG-001 compile failure names the expression");
      Register_Routine
        (Test, Compile_Failure_Names_Script_File'Access,
         "SCRIPT-DIAG-002 compile failure names the script file");
      Register_Routine
        (Test, Unreadable_Script_File_Is_Fatal'Access,
         "SCRIPT-LOAD-001 unreadable script file is fatal");
      Register_Routine
        (Test, Compile_Failure_Leaves_Write_Target_Untouched'Access,
         "SCRIPT-WRITE-001 compile failure leaves w target untouched");
      Register_Routine
        (Test, Write_Target_Is_Created_Once'Access,
         "SCRIPT-WRITE-002 w target is created once");
      Register_Routine
        (Test, Compiled_Program_Reports_Destinations'Access,
         "SCRIPT-WRITE-003 compiled program reports destinations");
   end Register_Tests;

end Sed_Test_Suite.Scripts;

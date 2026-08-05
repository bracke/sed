with AUnit.Assertions;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Project_Tools.Files;
with Project_Tools.Processes;
with Sed_Test_Suite.Support;

package body Sed_Test_Suite.Process is

   use AUnit.Assertions;

   package U renames Ada.Strings.Unbounded;
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   LF : constant Character := ASCII.LF;

   overriding function Name (Test : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (Test);
   begin
      return AUnit.Format ("sed process level");
   end Name;

   type Process_Result is record
      Output : U.Unbounded_String := U.Null_Unbounded_String;
      Errors : U.Unbounded_String := U.Null_Unbounded_String;
      Status : Integer := -1;
   end record;

   --  Absolute path of the executable under test.
   function Executable return String;

   --  A directory of this case's own, emptied first so a rerun starts clean.
   function Workspace (Case_Name : String) return String;

   --  Run the executable and capture both streams and the exit status.
   --
   --  Redirection is written into the command rather than left to the caller,
   --  so standard output and standard error stay separated: a test that
   --  claims standard output is empty has to be able to see that it is.
   function Run
     (Work : String;
      Arguments : String;
      Standard_Input : String := "";
      Environment : String := "") return Process_Result;

   --  Contents of a file the run created, or an empty string.
   function File_Body (Work : String; Name : String) return String;

   ----------------
   -- Executable --
   ----------------

   function Executable return String is
      Candidates : constant array (1 .. 2) of U.Unbounded_String :=
        [U.To_Unbounded_String ("../bin/sed"),
         U.To_Unbounded_String ("bin/sed")];
   begin
      for Candidate of Candidates loop
         declare
            Path : constant String := U.To_String (Candidate);
         begin
            if Files.File_Exists (Path) then
               return Ada.Directories.Full_Name (Path);
            end if;
         end;
      end loop;

      return "";
   end Executable;

   ---------------
   -- Workspace --
   ---------------

   function Workspace (Case_Name : String) return String is
      Root : constant String := "obj/process";
      Path : constant String := Files.Join (Root, Case_Name);
   begin
      if Files.Directory_Exists (Path) then
         Files.Delete_Tree (Path);
      end if;

      Ada.Directories.Create_Path (Path);
      return Ada.Directories.Full_Name (Path);
   end Workspace;

   ---------
   -- Run --
   ---------

   function Run
     (Work : String;
      Arguments : String;
      Standard_Input : String := "";
      Environment : String := "") return Process_Result
   is
      Input_Path : constant String := Files.Join (Work, ".stdin");
      Output_Path : constant String := Files.Join (Work, ".stdout");
      Errors_Path : constant String := Files.Join (Work, ".stderr");
      Program : constant String := Executable;
      Result : Process_Result;
   begin
      Assert (Program'Length > 0, "the sed executable was built before the run");

      Files.Write_Raw_File (Input_Path, Standard_Input);

      Result.Status :=
        Processes.Run_Shell_In_Directory
          (Directory => Work,
           Command =>
             Environment & Processes.Shell_Quote (Program) & " " & Arguments
             & " <" & Processes.Shell_Quote (Input_Path)
             & " >" & Processes.Shell_Quote (Output_Path)
             & " 2>" & Processes.Shell_Quote (Errors_Path));

      Result.Output := U.To_Unbounded_String (Files.Read_Raw_File (Output_Path));
      Result.Errors := U.To_Unbounded_String (Files.Read_Raw_File (Errors_Path));
      return Result;
   end Run;

   ---------------
   -- File_Body --
   ---------------

   function File_Body (Work : String; Name : String) return String is
      Path : constant String := Files.Join (Work, Name);
   begin
      if not Files.File_Exists (Path) then
         return "";
      end if;

      return Files.Read_Raw_File (Path);
   end File_Body;

   --  PROC-ADMIN-001: help and version reach standard output and exit zero.

   procedure Administrative_Output
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("admin");
      Help : constant Process_Result := Run (Work, "--help");
      Version : constant Process_Result := Run (Work, "--version");
   begin
      Assert (Help.Status = 0, "PROC-ADMIN-001 --help exits 0");
      Assert
        (Support.Contains (U.To_String (Help.Output), "Usage:"),
         "PROC-ADMIN-001 --help writes usage to standard output");
      Assert
        (Support.Contains (U.To_String (Help.Output), "--version"),
         "PROC-ADMIN-001 --help lists every registered option");
      Assert
        (U.To_String (Help.Errors) = "",
         "PROC-ADMIN-001 --help writes nothing to standard error");

      Assert (Version.Status = 0, "PROC-ADMIN-001 --version exits 0");
      Assert
        (Support.Contains (U.To_String (Version.Output), "sedlib"),
         "PROC-ADMIN-001 --version names the engine");
      Assert
        (U.To_String (Version.Errors) = "",
         "PROC-ADMIN-001 --version writes nothing to standard error");

      --  The catalogue is found relative to the executable, so these lines
      --  are real messages rather than bare keys.
      Assert
        (not Support.Contains (U.To_String (Help.Output), "sed.help."),
         "PROC-ADMIN-001 the catalogue resolved relative to the executable");
   end Administrative_Output;

   --  PROC-ERROR-001: an invalid invocation exits 2 and says so on standard
   --  error only.

   procedure Invocation_Failures
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("invocation");
      Unknown : constant Process_Result := Run (Work, "-x");
      Missing_Argument : constant Process_Result := Run (Work, "-e");
      No_Script : constant Process_Result := Run (Work, "");
   begin
      Assert (Unknown.Status = 2, "PROC-ERROR-001 an unknown option exits 2");
      Assert
        (U.To_String (Unknown.Output) = "",
         "PROC-ERROR-001 standard output stays empty");
      Assert
        (Support.Contains (U.To_String (Unknown.Errors), "unrecognized option"),
         "PROC-ERROR-001 the failure is named");
      Assert
        (Support.Contains (U.To_String (Unknown.Errors), "--help"),
         "PROC-ERROR-001 the help hint is offered");

      Assert
        (Missing_Argument.Status = 2,
         "PROC-ERROR-001 a missing option argument exits 2");
      Assert (No_Script.Status = 2, "PROC-ERROR-001 no script exits 2");
   end Invocation_Failures;

   --  PROC-ERROR-002: a script that will not compile exits 1 and names where.

   procedure Compilation_Failures
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("compile");
      Malformed : constant Process_Result :=
        Run (Work, "-e 'p' -e 'ZZZ'", "x" & LF);
      Bad_Expression : constant Process_Result :=
        Run (Work, "-- 's/[/y/'", "x" & LF);
   begin
      Assert (Malformed.Status = 1, "PROC-ERROR-002 a malformed script exits 1");
      Assert
        (U.To_String (Malformed.Output) = "",
         "PROC-ERROR-002 no input is processed");
      Assert
        (Support.Contains
           (U.To_String (Malformed.Errors), "command line expression 2"),
         "PROC-ERROR-002 the failing expression is named");

      Assert
        (Bad_Expression.Status = 1,
         "PROC-ERROR-002 an invalid expression exits 1");
      Assert
        (Support.Contains
           (U.To_String (Bad_Expression.Errors), "invalid regular expression"),
         "PROC-ERROR-002 the expression failure is classified");
   end Compilation_Failures;

   --  PROC-SCRIPT-001: script files and ordered expressions.

   procedure Script_Sources
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("scripts");
   begin
      Files.Write_Raw_File (Files.Join (Work, "first.sed"), "s/x/1/" & LF);
      Files.Write_Raw_File (Files.Join (Work, "last.sed"), "s/2/3/" & LF);
      Files.Write_Raw_File (Files.Join (Work, "input.txt"), "x" & LF);

      declare
         From_File : constant Process_Result :=
           Run (Work, "-f first.sed input.txt");
         Ordered : constant Process_Result :=
           Run (Work,
                "-f first.sed -e 's/1/2/' -f last.sed -e 's/3/z/' input.txt");
         Unreadable : constant Process_Result :=
           Run (Work, "-f missing.sed input.txt");
      begin
         Assert (From_File.Status = 0, "PROC-SCRIPT-001 a script file runs");
         Assert
           (U.To_String (From_File.Output) = "1" & LF,
            "PROC-SCRIPT-001 the script file was applied");

         Assert
           (U.To_String (Ordered.Output) = "z" & LF,
            "PROC-SCRIPT-001 sources apply in command-line order");

         Assert
           (Unreadable.Status = 1,
            "PROC-SCRIPT-001 an unreadable script file exits 1");
         Assert
           (U.To_String (Unreadable.Output) = "",
            "PROC-SCRIPT-001 no input is read when the script cannot be");
      end;
   end Script_Sources;

   --  PROC-INPUT-001: operands form one logical stream.

   procedure Input_Operands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("input");
   begin
      Files.Write_Raw_File (Files.Join (Work, "a.txt"), "a" & LF & "b" & LF);
      Files.Write_Raw_File (Files.Join (Work, "b.txt"), "c" & LF);
      Files.Write_Raw_File (Files.Join (Work, "empty.txt"), "");

      declare
         Numbering : constant Process_Result :=
           Run (Work, "-n -- '=' a.txt b.txt");
         Final : constant Process_Result :=
           Run (Work, "-n -- '$p' a.txt b.txt");
         Trailing_Empty : constant Process_Result :=
           Run (Work, "-n -- '$p' a.txt empty.txt");
         From_Stdin : constant Process_Result :=
           Run (Work, "-n -- 'p'", "s" & LF);
         Between : constant Process_Result :=
           Run (Work, "-n -- 'p' a.txt - b.txt", "s" & LF);
         Repeated : constant Process_Result :=
           Run (Work, "-n -- 'p' - -", "s" & LF);
      begin
         Assert
           (U.To_String (Numbering.Output) = "1" & LF & "2" & LF & "3" & LF,
            "PROC-INPUT-001 line numbers continue across operands");
         Assert
           (U.To_String (Final.Output) = "c" & LF,
            "PROC-INPUT-001 the final address matches the last line overall");
         Assert
           (U.To_String (Trailing_Empty.Output) = "b" & LF,
            "PROC-INPUT-001 a trailing empty operand does not move the end");
         Assert
           (U.To_String (From_Stdin.Output) = "s" & LF,
            "PROC-INPUT-001 standard input is read with no operand");
         Assert
           (U.To_String (Between.Output) = "a" & LF & "b" & LF & "s" & LF & "c" & LF,
            "PROC-INPUT-001 a hyphen operand takes its place in order");
         Assert
           (U.To_String (Repeated.Output) = "s" & LF,
            "PROC-INPUT-001 a repeated hyphen does not rewind");
      end;
   end Input_Operands;

   --  PROC-INPUT-002: a missing operand between readable ones is recoverable.

   procedure Recoverable_Input_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("recoverable");
   begin
      Files.Write_Raw_File (Files.Join (Work, "a.txt"), "a" & LF);
      Files.Write_Raw_File (Files.Join (Work, "b.txt"), "b" & LF);

      declare
         Result : constant Process_Result :=
           Run (Work, "-n -- 'p' a.txt missing.txt b.txt");
      begin
         Assert
           (U.To_String (Result.Output) = "a" & LF & "b" & LF,
            "PROC-INPUT-002 the readable operands are still processed");
         Assert
           (Result.Status = 1,
            "PROC-INPUT-002 the run reports a processing failure");
         Assert
           (Support.Contains (U.To_String (Result.Errors), "missing.txt"),
            "PROC-INPUT-002 the unreadable operand is named");
      end;
   end Recoverable_Input_Failure;

   --  PROC-INPUT-003: a final line without a newline round-trips byte for
   --  byte, which is the property most easily lost at a real stream boundary.

   procedure Unterminated_Final_Line
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("unterminated");
      Copied : constant Process_Result := Run (Work, "-- 's/a/b/'", "a");
      Printed : constant Process_Result := Run (Work, "-- 'p'", "a");
      Terminated : constant Process_Result := Run (Work, "-- 's/a/b/'", "a" & LF);
   begin
      Assert
        (U.To_String (Copied.Output) = "b",
         "PROC-INPUT-003 a missing final newline stays missing");
      Assert
        (U.To_String (Printed.Output) = "a" & LF & "a",
         "PROC-INPUT-003 only the last line written may lack a newline");
      Assert
        (U.To_String (Terminated.Output) = "b" & LF,
         "PROC-INPUT-003 a terminated final line keeps its newline");
   end Unterminated_Final_Line;

   --  PROC-FILE-001: r and w reach the real filesystem.

   procedure File_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("files");
   begin
      Files.Write_Raw_File (Files.Join (Work, "extra.txt"), "X" & LF);

      declare
         Read : constant Process_Result :=
           Run (Work, "-- 'r extra.txt'", "a" & LF);
         Missing : constant Process_Result :=
           Run (Work, "-- 'r absent.txt'", "a" & LF);
         Written : constant Process_Result :=
           Run (Work, "-n -- '/b/w kept.txt'", "a" & LF & "b" & LF);
      begin
         Assert
           (U.To_String (Read.Output) = "a" & LF & "X" & LF,
            "PROC-FILE-001 r appends the file contents");
         Assert
           (Missing.Status = 0 and then U.To_String (Missing.Errors) = "",
            "PROC-FILE-001 a missing r file is not an error condition");

         Assert (Written.Status = 0, "PROC-FILE-001 w succeeds");
         Assert
           (File_Body (Work, "kept.txt") = "b" & LF,
            "PROC-FILE-001 w created the file with the selected lines");
      end;
   end File_Commands;

   --  PROC-FILE-002: a script that fails to compile never truncates a w
   --  target, because the file is only created after compilation succeeds.

   procedure Write_Target_Untouched_On_Failure
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("write_guard");
   begin
      Files.Write_Raw_File (Files.Join (Work, "out.txt"), "existing" & LF);

      declare
         Result : constant Process_Result :=
           Run (Work, "-e 'w out.txt' -e 'ZZZ'", "x" & LF);
      begin
         Assert (Result.Status = 1, "PROC-FILE-002 the run fails");
         Assert
           (File_Body (Work, "out.txt") = "existing" & LF,
            "PROC-FILE-002 the write target was never opened");
      end;
   end Write_Target_Untouched_On_Failure;

   --  PROC-STYLE-001: colour reaches a real standard error, and never the
   --  program's own output.

   procedure Styling_Modes
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("style");
      Escape : constant String := [1 => ASCII.ESC];
      Never : constant Process_Result := Run (Work, "--color=never -x");
      Always : constant Process_Result := Run (Work, "--color=always -x");
      Auto : constant Process_Result := Run (Work, "--color=auto -x");
   begin
      Assert
        (not Support.Contains (U.To_String (Never.Errors), Escape),
         "PROC-STYLE-001 never emits no escape sequences");
      Assert
        (Support.Contains (U.To_String (Always.Errors), Escape),
         "PROC-STYLE-001 always emits escape sequences");
      Assert
        (not Support.Contains (U.To_String (Auto.Errors), Escape),
         "PROC-STYLE-001 auto stays plain when standard error is a file");

      declare
         Data : constant Process_Result :=
           Run (Work, "--color=always -n -- 'p'", "line" & LF);
      begin
         Assert
           (U.To_String (Data.Output) = "line" & LF,
            "PROC-STYLE-001 program data is never styled");
      end;
   end Styling_Modes;

   --  PROC-LOCALE-001: the environment selects the message locale.

   procedure Locale_Selection
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("locale");
      English : constant Process_Result :=
        Run (Work, "-x", Environment => "LC_ALL=en_US.UTF-8 ");
      Danish : constant Process_Result :=
        Run (Work, "-x", Environment => "LC_ALL=da_DK.UTF-8 ");
      Posix : constant Process_Result :=
        Run (Work, "-x", Environment => "LC_ALL=C ");
   begin
      Assert
        (Support.Contains (U.To_String (English.Errors), "unrecognized option"),
         "PROC-LOCALE-001 the requested locale renders its own text");
      Assert
        (Support.Contains (U.To_String (Danish.Errors), "ukendt tilvalg"),
         "PROC-LOCALE-001 an alternate locale renders its own text");
      Assert
        (Support.Contains (U.To_String (Posix.Errors), "unrecognized option"),
         "PROC-LOCALE-001 the POSIX locale falls back to the default");
      Assert
        (Support.Contains (U.To_String (Danish.Errors), "'-x'"),
         "PROC-LOCALE-001 the option spelling is not translated");
   end Locale_Selection;

   --  PROC-STATUS-001: statuses accumulate across a whole run.

   procedure Status_Aggregation
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Work : constant String := Workspace ("status");
   begin
      Files.Write_Raw_File (Files.Join (Work, "a.txt"), "a" & LF);

      declare
         Success : constant Process_Result := Run (Work, "-n -- 'p' a.txt");
         Processing : constant Process_Result :=
           Run (Work, "-n -- 'p' a.txt missing.txt");
         Invocation : constant Process_Result := Run (Work, "--unknown");
      begin
         --  A run that both succeeds on one operand and fails on another
         --  keeps the failure: a later success cannot erase it.
         Assert (Success.Status = 0, "PROC-STATUS-001 a clean run exits 0");
         Assert
           (Processing.Status = 1,
            "PROC-STATUS-001 a processing failure survives a later success");
         Assert
           (Invocation.Status = 2,
            "PROC-STATUS-001 an invocation failure exits 2");
      end;
   end Status_Aggregation;

   overriding procedure Register_Tests (Test : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (Test, Administrative_Output'Access,
         "PROC-ADMIN-001 help and version");
      Register_Routine
        (Test, Invocation_Failures'Access,
         "PROC-ERROR-001 invocation failures");
      Register_Routine
        (Test, Compilation_Failures'Access,
         "PROC-ERROR-002 compilation failures");
      Register_Routine
        (Test, Script_Sources'Access,
         "PROC-SCRIPT-001 script files and ordering");
      Register_Routine
        (Test, Input_Operands'Access,
         "PROC-INPUT-001 input operands");
      Register_Routine
        (Test, Recoverable_Input_Failure'Access,
         "PROC-INPUT-002 recoverable input failure");
      Register_Routine
        (Test, Unterminated_Final_Line'Access,
         "PROC-INPUT-003 unterminated final line");
      Register_Routine
        (Test, File_Commands'Access,
         "PROC-FILE-001 r and w");
      Register_Routine
        (Test, Write_Target_Untouched_On_Failure'Access,
         "PROC-FILE-002 w target untouched on failure");
      Register_Routine
        (Test, Styling_Modes'Access,
         "PROC-STYLE-001 styling modes");
      Register_Routine
        (Test, Locale_Selection'Access,
         "PROC-LOCALE-001 locale selection");
      Register_Routine
        (Test, Status_Aggregation'Access,
         "PROC-STATUS-001 status aggregation");
   end Register_Tests;

end Sed_Test_Suite.Process;

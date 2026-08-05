with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Project_Tools.Files;
with Project_Tools.Processes;
with Sed.Command_Line.Options;
with Sed.Diagnostics;
with Sed.Diagnostics.Registry;
with Sed.Version;

--  Project tooling for the sed crate.
--
--  Everything the project needs done to itself is done here, in Ada, through
--  project_tools: there is no shell script, makefile or other non-Ada build
--  machinery anywhere in the repository, and "sed_tools verify" enforces that.
--
--  Usage: sed_tools build | test | verify | docs | clean | release
procedure Sed_Tools is

   package U renames Ada.Strings.Unbounded;
   package IO renames Ada.Text_IO;
   package Files renames Project_Tools.Files;
   package Processes renames Project_Tools.Processes;

   Failures : Natural := 0;

   --  Repository root, found by walking up to the root project file.
   function Root return String;

   --  Report a check result and remember any failure.
   procedure Check (Condition : Boolean; Label : String);

   --  Report progress.
   procedure Note (Text : String);

   --  Run a command in a directory, counting a non-zero status as a failure.
   procedure Step (Label : String; Directory : String; Args : String);

   --  Split a space-separated argument string into a vector.
   function Split (Text : String) return Processes.Argument_Vectors.Vector;

   procedure Do_Build;
   procedure Do_Docs;
   procedure Do_Test;
   procedure Do_Verify;
   procedure Do_Clean;
   procedure Do_Release;

   ----------
   -- Root --
   ----------

   function Root return String is
      Found : constant String :=
        Files.Find_Root_Upward (Ada.Directories.Current_Directory, "sed.gpr");
   begin
      if Found'Length = 0 then
         return Ada.Directories.Current_Directory;
      end if;

      return Found;
   end Root;

   ----------
   -- Note --
   ----------

   procedure Note (Text : String) is
   begin
      IO.Put_Line ("sed_tools: " & Text);
   end Note;

   -----------
   -- Check --
   -----------

   procedure Check (Condition : Boolean; Label : String) is
   begin
      if Condition then
         IO.Put_Line ("  ok   " & Label);
      else
         IO.Put_Line ("  FAIL " & Label);
         Failures := Failures + 1;
      end if;
   end Check;

   -----------
   -- Split --
   -----------

   function Split (Text : String) return Processes.Argument_Vectors.Vector is
      Result : Processes.Argument_Vectors.Vector;
      First : Natural := Text'First;
   begin
      for Index in Text'Range loop
         if Text (Index) = ' ' then
            if Index > First then
               Result.Append (Processes.Argument (Text (First .. Index - 1)));
            end if;

            First := Index + 1;
         end if;
      end loop;

      if Text'Last >= First then
         Result.Append (Processes.Argument (Text (First .. Text'Last)));
      end if;

      return Result;
   end Split;

   ----------
   -- Step --
   ----------

   procedure Step (Label : String; Directory : String; Args : String) is
      --  Spawning does not search PATH, so the launcher is resolved first.
      Program : constant String := Processes.Locate_Command ("alr");
   begin
      if Program'Length = 0 then
         Check (False, "alr is on PATH");
         return;
      end if;

      Check
        (Processes.Run_Status (Label, Directory, Program, Split (Args)) = 0,
         Label);
   end Step;

   --------------
   -- Do_Build --
   --------------

   procedure Do_Build is
   begin
      Note ("building through Alire");
      Step ("build sed", Root, "-n build");
      Step ("build sed_tests", Files.Join (Root, "tests"), "-n build");
   end Do_Build;

   -------------
   -- Do_Docs --
   -------------

   procedure Do_Docs is
      Program : constant String := Files.Join (Root, "bin/sed");
      Status : Integer;
   begin
      Note ("checking administrative output");

      Status :=
        Processes.Run_Status
          ("sed --version", Root, Program,
           Split ("--version"));
      Check (Status = 0, "sed --version succeeds");

      Status :=
        Processes.Run_Status
          ("sed --help", Root, Program, Split ("--help"));
      Check (Status = 0, "sed --help succeeds");
   end Do_Docs;

   -------------
   -- Do_Test --
   -------------

   procedure Do_Test is
      Tests : constant String := Files.Join (Root, "tests");
      Status : Integer;
   begin
      Do_Build;

      Note ("running the AUnit suite");
      Status :=
        Processes.Run_Status
          ("sed_tests_main", Tests, "./bin/sed_tests_main",
           Processes.No_Arguments);
      Check (Status = 0, "the AUnit suite passes");

      Do_Docs;
   end Do_Test;

   ---------------
   -- Do_Verify --
   ---------------

   procedure Do_Verify is
      Source_Root : constant String := Files.Join (Root, "src");
      Catalog : constant String :=
        Files.Join (Root, "share/sed/messages/catalog.txt");

      Skipped : constant Files.Name_List :=
        [U.To_Unbounded_String ("alire"),
         U.To_Unbounded_String ("obj"),
         U.To_Unbounded_String ("bin"),
         U.To_Unbounded_String (".git")];

      Forbidden : constant array (1 .. 7) of U.Unbounded_String :=
        [U.To_Unbounded_String ("*.sh"),
         U.To_Unbounded_String ("*.py"),
         U.To_Unbounded_String ("*.pl"),
         U.To_Unbounded_String ("*.rb"),
         U.To_Unbounded_String ("*.js"),
         U.To_Unbounded_String ("Makefile"),
         U.To_Unbounded_String ("CMakeLists.txt")];

      Markers : constant array (1 .. 6) of U.Unbounded_String :=
        [U.To_Unbounded_String ("TODO"),
         U.To_Unbounded_String ("FIXME"),
         U.To_Unbounded_String ("XXX"),
         U.To_Unbounded_String ("NOT IMPLEMENTED"),
         U.To_Unbounded_String ("PLACEHOLDER"),
         U.To_Unbounded_String ("STUB")];

      Documents : constant array (1 .. 14) of U.Unbounded_String :=
        [U.To_Unbounded_String ("README.md"),
         U.To_Unbounded_String ("CHANGELOG.md"),
         U.To_Unbounded_String ("LICENSE"),
         U.To_Unbounded_String ("doc/architecture.md"),
         U.To_Unbounded_String ("doc/command-line.md"),
         U.To_Unbounded_String ("doc/sedlib-integration.md"),
         U.To_Unbounded_String ("doc/posix-conformance.md"),
         U.To_Unbounded_String ("doc/input-output-model.md"),
         U.To_Unbounded_String ("doc/diagnostics-and-localization.md"),
         U.To_Unbounded_String ("doc/testing.md"),
         U.To_Unbounded_String ("doc/tooling.md"),
         U.To_Unbounded_String ("doc/release.md"),
         U.To_Unbounded_String ("doc/security.md"),
         U.To_Unbounded_String ("doc/ai-implementation-guide.md")];

      --  Conformance gaps that are still open. Every one listed must have a
      --  test that reproduces it. The list is empty because none are open;
      --  recording a new gap means adding its identifier here, describing it
      --  in doc/posix-conformance.md, and writing a test that reproduces it.
      Gaps : constant Files.Name_List := [1 .. 0 => <>];

   begin
      Do_Test;

      Note ("auditing the repository");

      --  All tooling is Ada: no other build machinery may appear anywhere.
      for Pattern of Forbidden loop
         declare
            Found : constant Files.Path_List :=
              Files.List_Tree (Root, U.To_String (Pattern), Skipped);
         begin
            Check
              (Found'Length = 0,
               "no " & U.To_String (Pattern) & " tooling file is present");
         end;
      end loop;

      --  No claimed feature may be left as a marker in production code.
      declare
         Sources : constant Files.Path_List :=
           Files.List_Tree (Source_Root, "*.ad*");
      begin
         Check (Sources'Length > 0, "production sources were found");

         for Marker of Markers loop
            declare
               Hit : Boolean := False;
            begin
               for Path of Sources loop
                  if Files.File_Contains
                       (U.To_String (Path), U.To_String (Marker))
                  then
                     Hit := True;
                     IO.Put_Line
                       ("       " & U.To_String (Path) & " contains "
                        & U.To_String (Marker));
                  end if;
               end loop;

               Check
                 (not Hit,
                  "production sources contain no " & U.To_String (Marker));
            end;
         end loop;
      end;

      --  Every diagnostic code must resolve in every shipped locale.
      Check (Files.File_Exists (Catalog), "the message catalogue is present");

      for Code in Sed.Diagnostics.Diagnostic_Code loop
         declare
            Key : constant String :=
              Sed.Diagnostics.Registry.Message_Key (Code);
         begin
            Check
              (Files.File_Contains (Catalog, "en." & Key & " ="),
               "the catalogue defines " & Key);
            Check
              (Files.File_Contains (Catalog, "da." & Key & " ="),
               "the alternate locale defines " & Key);
         end;
      end loop;

      --  Help is generated from the option registry, so every registered
      --  option must have a help line in every locale.
      for Id in Sed.Command_Line.Options.Option_Id loop
         declare
            Key : constant String := Sed.Command_Line.Options.Help_Key (Id);
         begin
            Check
              (Files.File_Contains (Catalog, "en." & Key & " =")
                 and then Files.File_Contains (Catalog, "da." & Key & " ="),
               "the catalogue documents "
               & Sed.Command_Line.Options.Spelling (Id));
         end;
      end loop;

      --  The reported engine version must match the manifest pin.
      Check
        (Files.File_Contains
           (Files.Join (Root, "alire.toml"), Sed.Version.Engine_Version),
         "the manifest pins the engine version the program reports");

      Check
        (Files.File_Contains
           (Files.Join (Root, "CHANGELOG.md"), Sed.Version.Value),
         "the changelog records version " & Sed.Version.Value);

      --  Documentation the project promises must exist.
      for Document of Documents loop
         Check
           (Files.File_Exists (Files.Join (Root, U.To_String (Document))),
            U.To_String (Document) & " is present");
      end loop;

      --  The conformance document and this list must agree about what is
      --  still open, so a gap cannot be closed in one and left in the other.
      Check
        (Files.File_Contains
           (Files.Join (Root, "doc/posix-conformance.md"),
            "No conformance gaps are open")
         = (Gaps'Length = 0),
         "the conformance document agrees about open gaps");

      --  Every documented gap must have a test that reproduces it, so a gap
      --  cannot quietly outlive the behaviour it describes.
      for Gap of Gaps loop
         Check
           (Files.File_Contains
              (Files.Join (Root, "doc/posix-conformance.md"),
               U.To_String (Gap)),
            U.To_String (Gap) & " is documented");
         Check
           (Files.Any_File_Contains
              (Files.Join (Root, "tests/src"), U.To_String (Gap)),
            U.To_String (Gap) & " has a reproducing test");
      end loop;
   end Do_Verify;

   --------------
   -- Do_Clean --
   --------------

   procedure Do_Clean is
      Removable : constant array (1 .. 5) of U.Unbounded_String :=
        [U.To_Unbounded_String ("obj"),
         U.To_Unbounded_String ("bin"),
         U.To_Unbounded_String ("tests/obj"),
         U.To_Unbounded_String ("tests/bin"),
         U.To_Unbounded_String ("dist")];
   begin
      Note ("removing project-owned build artifacts");

      for Item of Removable loop
         declare
            Path : constant String := Files.Join (Root, U.To_String (Item));
         begin
            --  Only ever a directory the project itself generates, and only
            --  ever inside the repository root.
            if Path'Length > Root'Length
              and then Files.Directory_Exists (Path)
            then
               Files.Delete_Tree (Path);
               IO.Put_Line ("  removed " & U.To_String (Item));
            end if;
         end;
      end loop;
   end Do_Clean;

   ----------------
   -- Do_Release --
   ----------------

   procedure Do_Release is
   begin
      Note ("release gate for version " & Sed.Version.Value);
      Do_Verify;

      --  The program stays a prerelease until it has been exercised beyond
      --  its own suite, whether or not any conformance gap is recorded.
      Check
        (Sed.Version.Is_Prerelease,
         "the version is still a prerelease");
   end Do_Release;

   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0
      then "verify"
      else Ada.Command_Line.Argument (1));

begin
   if Command = "build" then
      Do_Build;
   elsif Command = "test" then
      Do_Test;
   elsif Command = "verify" then
      Do_Verify;
   elsif Command = "docs" then
      Do_Docs;
   elsif Command = "clean" then
      Do_Clean;
   elsif Command = "release" then
      Do_Release;
   else
      IO.Put_Line
        ("usage: sed_tools build | test | verify | docs | clean | release");
      Failures := Failures + 1;
   end if;

   if Failures = 0 then
      Note ("all checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Note (Natural'Image (Failures) & " check(s) failed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Sed_Tools;

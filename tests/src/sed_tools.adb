with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Project_Tools.Files;
with Project_Tools.Processes;
with Sed.Command_Line.Options;
with Sed.Diagnostics;
with Sed.Diagnostics.Registry;
with Sed_Registries;
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

      --  Traceability: every claim must cite a test, and every cited test
      --  must exist. Without the second half a table slowly fills with
      --  identifiers that were renamed or deleted, and still reads as proof.
      declare
         Test_Root : constant String := Files.Join (Root, "tests/src");

         Sources : constant Files.Path_List :=
           Files.List_Tree (Test_Root, "*.ad*");

         --  Whether Value occurs in Text.
         function Occurs (Text : String; Value : String) return Boolean;

         ------------
         -- Occurs --
         ------------

         function Occurs (Text : String; Value : String) return Boolean is
         begin
            if Value'Length = 0 or else Value'Length > Text'Length then
               return Value'Length = 0;
            end if;

            for Start in Text'First .. Text'Last - Value'Length + 1 loop
               if Text (Start .. Start + Value'Length - 1) = Value then
                  return True;
               end if;
            end loop;

            return False;
         end Occurs;

         --  Whether a test identifier occurs in a file that is not itself a
         --  registry.
         --
         --  The registries live in this same tree, so searching all of it
         --  would let every citation satisfy itself: the claim would be its
         --  own evidence. Only files that could actually contain a test count.
         function Test_Exists (Id : String) return Boolean is
         begin
            for Path of Sources loop
               declare
                  Name : constant String := U.To_String (Path);
               begin
                  if not Occurs (Name, "sed_registries")
                    and then Files.File_Contains (Name, Id)
                  then
                     return True;
                  end if;
               end;
            end loop;

            return False;
         end Test_Exists;

         --  Check every space-separated identifier in a citation.
         procedure Check_Citation (Owner : String; Citation : String);

         ---------------------
         -- Check_Citation --
         ---------------------

         procedure Check_Citation (Owner : String; Citation : String) is
            First : Natural := Citation'First;
         begin
            Check (Citation'Length > 0, Owner & " cites at least one test");

            for Index in Citation'First .. Citation'Last + 1 loop
               if Index > Citation'Last or else Citation (Index) = ' ' then
                  if Index > First then
                     declare
                        Id : constant String := Citation (First .. Index - 1);
                     begin
                        Check
                          (Test_Exists (Id),
                           Owner & " cites test " & Id & ", which exists");
                     end;
                  end if;

                  First := Index + 1;
               end if;
            end loop;
         end Check_Citation;

      begin
         for Item of Sed_Registries.Requirements loop
            Check_Citation
              (Sed_Registries.Text.To_String (Item.Id),
               Sed_Registries.Text.To_String (Item.Tests));
         end loop;

         for Item of Sed_Registries.Commands loop
            Check_Citation
              ("command " & Item.Symbol,
               Sed_Registries.Text.To_String (Item.Tests));
         end loop;

         for Code in Sed.Diagnostics.Diagnostic_Code loop
            Check_Citation
              (Sed.Diagnostics.Diagnostic_Code'Image (Code),
               Sed_Registries.Text.To_String
                 (Sed_Registries.Diagnostic_Coverage (Code).Tests));
         end loop;
      end;

      --  Every POSIX command the registry claims must also appear in the
      --  conformance document, so the two cannot describe different programs.
      for Item of Sed_Registries.Commands loop
         if Item.Posix_Required then
            declare
               Document : constant String :=
                 Files.Join (Root, "doc/posix-conformance.md");
            begin
               --  A command is documented either under its bare symbol or,
               --  for the text commands, under the POSIX form that carries a
               --  trailing backslash.
               Check
                 (Files.File_Contains (Document, "`" & Item.Symbol & "`")
                    or else Files.File_Contains
                              (Document, "`" & Item.Symbol & "\`"),
                  "the conformance document covers command " & Item.Symbol);
            end;
         end if;
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
      Version : constant String := Sed.Version.Value;
      Dist : constant String := Files.Join (Root, "dist");
      Stage : constant String := Files.Join (Dist, "stage");
      Staged_Sed : constant String := Files.Join (Stage, "bin/sed");
      Archive : constant String :=
        Files.Join (Dist, "sed-" & Version & "-source.tar.gz");
      Manifest : constant String :=
        Files.Join (Dist, "sed-" & Version & "-manifest.txt");
      Checksums : constant String :=
        Files.Join (Dist, "sed-" & Version & "-checksums.txt");

      --  Run a shell pipeline from the repository root.
      function Shell (Command : String) return Integer
        is (Processes.Run_Shell_In_Directory (Root, Command, Quiet => True));

      --  Run the staged executable and compare its output byte for byte.
      procedure Smoke
        (Label : String;
         Arguments : String;
         Input : String;
         Expected : String);

      -----------
      -- Smoke --
      -----------

      procedure Smoke
        (Label : String;
         Arguments : String;
         Input : String;
         Expected : String)
      is
         Work : constant String := Files.Join (Dist, "smoke");
         In_Path : constant String := Files.Join (Work, "in");
         Out_Path : constant String := Files.Join (Work, "out");
      begin
         Ada.Directories.Create_Path (Work);
         Files.Write_Raw_File (In_Path, Input);

         declare
            Status : constant Integer :=
              Shell
                (Processes.Shell_Quote (Staged_Sed) & " " & Arguments
                 & " <" & Processes.Shell_Quote (In_Path)
                 & " >" & Processes.Shell_Quote (Out_Path) & " 2>/dev/null");
         begin
            Check
              (Status = 0 and then Files.Read_Raw_File (Out_Path) = Expected,
               "staged smoke test: " & Label);
         end;
      end Smoke;

      LF : constant Character := ASCII.LF;

   begin
      Note ("release gate for version " & Version);

      --  The archive is built from committed state, so an uncommitted change
      --  would ship as something the repository does not record.
      Check
        (Processes.Locate_Command ("git")'Length > 0, "git is available");
      Check
        (Shell ("git diff --quiet && git diff --cached --quiet") = 0,
         "the working tree is clean");

      Do_Verify;

      --  The program stays a prerelease until it has been exercised beyond
      --  its own suite, whether or not any conformance gap is recorded.
      Check (Sed.Version.Is_Prerelease, "the version is still a prerelease");

      Note ("building with release settings");
      Step ("release build", Root, "-n build --release");

      Note ("staging the installation");

      if Files.Directory_Exists (Dist) then
         Files.Delete_Tree (Dist);
      end if;

      Ada.Directories.Create_Path (Files.Join (Stage, "bin"));
      Ada.Directories.Create_Path (Files.Join (Stage, "share/sed/messages"));
      Files.Copy_File (Files.Join (Root, "bin/sed"), Staged_Sed);
      Files.Copy_File
        (Files.Join (Root, "share/sed/messages/catalog.txt"),
         Files.Join (Stage, "share/sed/messages/catalog.txt"));
      Check (Shell ("chmod +x " & Processes.Shell_Quote (Staged_Sed)) = 0,
             "the staged executable is executable");

      --  The staged tree is the layout an installation has, so running the
      --  smoke tests here also proves the catalogue resolves relative to the
      --  executable rather than through the source tree.
      Note ("running smoke tests against the staged executable");
      Smoke ("default printing", "-- 's/alpha/one/'",
             "alpha" & LF & "beta" & LF, "one" & LF & "beta" & LF);
      Smoke ("suppressed printing", "-n -- '/beta/p'",
             "alpha" & LF & "beta" & LF, "beta" & LF);
      Smoke ("multiple expressions", "-e 's/a/A/' -e 's/b/B/'",
             "abc" & LF, "ABc" & LF);
      Smoke ("final line address", "-n -- '$p'",
             "a" & LF & "b" & LF, "b" & LF);
      Smoke ("unterminated final line", "-- 's/a/b/'", "a", "b");
      Smoke ("hold space", "-n -- '1!G;h;$p'",
             "a" & LF & "b" & LF, "b" & LF & "a" & LF);
      Smoke ("basic regular expression", "-- 's/\(ab\)\1/X/'",
             "abab" & LF, "X" & LF);

      declare
         Localized : constant Integer :=
           Shell
             ("LC_ALL=da_DK.UTF-8 " & Processes.Shell_Quote (Staged_Sed)
              & " --unknown 2>" & Processes.Shell_Quote
                (Files.Join (Dist, "smoke/err")));
      begin
         Check (Localized = 2, "staged invocation failure exits 2");
         Check
           (Files.File_Contains
              (Files.Join (Dist, "smoke/err"), "ukendt tilvalg"),
            "the staged catalogue resolves relative to the executable");
      end;

      Note ("creating release artefacts");

      --  git archive takes exactly the committed files, so build output and
      --  local state cannot reach the archive by accident, and the result is
      --  reproducible for a given commit. gzip -n keeps the name and
      --  timestamp out of the compressed stream.
      Check
        (Shell
           ("git archive --format=tar --prefix=" & "sed-" & Version & "/ HEAD"
            & " | gzip -n > " & Processes.Shell_Quote (Archive)) = 0,
         "the source archive was created");
      Check (Files.File_Exists (Archive), "the source archive exists");

      --  An archive that is missing what the project promises is worse than
      --  no archive, so its contents are checked rather than assumed.
      declare
         Listing : constant String := Files.Join (Dist, "listing.txt");
         Required : constant Files.Name_List :=
           [U.To_Unbounded_String ("alire.toml"),
            U.To_Unbounded_String ("sed.gpr"),
            U.To_Unbounded_String ("LICENSE"),
            U.To_Unbounded_String ("README.md"),
            U.To_Unbounded_String ("CHANGELOG.md"),
            U.To_Unbounded_String ("src/main/sed_main.adb"),
            U.To_Unbounded_String ("share/sed/messages/catalog.txt"),
            U.To_Unbounded_String ("tests/alire.toml"),
            U.To_Unbounded_String ("doc/posix-conformance.md")];
      begin
         Check
           (Shell
              ("tar -tzf " & Processes.Shell_Quote (Archive) & " > "
               & Processes.Shell_Quote (Listing)) = 0,
            "the archive can be listed");

         for Item of Required loop
            Check
              (Files.File_Contains
                 (Listing, "sed-" & Version & "/" & U.To_String (Item)),
               "the archive contains " & U.To_String (Item));
         end loop;

         --  Build output must never ship.
         for Excluded of Files.Name_List'
           [U.To_Unbounded_String ("/obj/"),
            U.To_Unbounded_String ("/bin/"),
            U.To_Unbounded_String ("/alire/")]
         loop
            Check
              (not Files.File_Contains (Listing, U.To_String (Excluded)),
               "the archive excludes " & U.To_String (Excluded));
         end loop;
      end;

      Check
        (Shell
           ("sha256sum " & Processes.Shell_Quote (Archive)
            & " | sed 's|.*/||' > " & Processes.Shell_Quote (Checksums)) = 0,
         "checksums were written");

      declare
         Commit : constant String :=
           Processes.Shell_Output_Trimmed ("git -C " & Root & " rev-parse HEAD");
      begin
         Files.Write_Text_File
           (Manifest,
            "name: " & Sed.Version.Crate & ASCII.LF
            & "version: " & Version & ASCII.LF
            & "license: " & Sed.Version.License & ASCII.LF
            & "engine: " & Sed.Version.Engine_Name & " "
            & Sed.Version.Engine_Version & ASCII.LF
            & "commit: " & Commit & ASCII.LF
            & "archive: " & Ada.Directories.Simple_Name (Archive) & ASCII.LF
            & "checksums: " & Ada.Directories.Simple_Name (Checksums)
            & ASCII.LF);
      end;

      Check (Files.File_Exists (Manifest), "the manifest was written");
      Check
        (Files.File_Contains (Manifest, Version),
         "the manifest records the version");

      Note ("release artefacts are in " & Dist);
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

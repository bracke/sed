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
   procedure Do_Prove;
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

      --  Layering. doc/architecture.md states which packages may name which
      --  dependency; stating it is not enforcing it, and an import added in
      --  the wrong place compiles perfectly well. These rules are the ones
      --  that keep sedlib, the catalogue and the terminal out of layers that
      --  must stay testable without them.
      declare
         Sources : constant Files.Path_List :=
           Files.List_Tree (Source_Root, "*.ad*");

         --  Only the named files may import Unit.
         procedure Restrict (Unit : String; Allowed : String);

         --  Files whose name begins with Prefix must not import Unit.
         procedure Forbid (Prefix : String; Unit : String);

         --------------
         -- Restrict --
         --------------

         procedure Restrict (Unit : String; Allowed : String) is
            Offenders : Natural := 0;
         begin
            for Path of Sources loop
               declare
                  Name : constant String := U.To_String (Path);
                  Simple : constant String :=
                    Ada.Directories.Simple_Name (Name);
               begin
                  if Files.File_Contains (Name, "with " & Unit)
                    and then not Occurs (Allowed, Simple)
                  then
                     Offenders := Offenders + 1;
                     IO.Put_Line ("       " & Simple & " imports " & Unit);
                  end if;
               end;
            end loop;

            Check (Offenders = 0, "only permitted units import " & Unit);
         end Restrict;

         ------------
         -- Forbid --
         ------------

         procedure Forbid (Prefix : String; Unit : String) is
            Offenders : Natural := 0;
         begin
            for Path of Sources loop
               declare
                  Name : constant String := U.To_String (Path);
                  Simple : constant String :=
                    Ada.Directories.Simple_Name (Name);
               begin
                  if Simple'Length >= Prefix'Length
                    and then Simple (Simple'First .. Simple'First + Prefix'Length - 1)
                             = Prefix
                    and then Files.File_Contains (Name, "with " & Unit)
                  then
                     Offenders := Offenders + 1;
                     IO.Put_Line ("       " & Simple & " imports " & Unit);
                  end if;
               end;
            end loop;

            Check (Offenders = 0, Prefix & "* does not import " & Unit);
         end Forbid;

      begin
         --  The engine, the catalogue and the terminal each have exactly one
         --  set of packages allowed to name them.
         Restrict
           ("Sedlib",
            "sed-engine.ads sed-engine.adb sed-scripts-compilation.ads"
            & " sed-scripts-compilation.adb sed-scripts-compilation-engine.ads"
            & " sed-scripts-compilation-engine.adb sed-execution.adb"
            & " sed-execution-environment.ads sed-execution-environment.adb");
         Restrict ("Messages", "sed-localization.ads sed-localization.adb");
         Restrict ("Terminal_Styles", "sed-terminal.adb");

         --  Standard output belongs to the output layer, so only the process
         --  stream adapter may reach Ada.Text_IO at all.
         Restrict ("Ada.Text_IO", "sed-io-process_streams.adb");

         --  Only the process adapters read the real argument vector.
         Restrict
           ("Ada.Command_Line",
            "sed-application.adb sed-environment.adb sed_main.adb");

         --  The command line opens nothing, renders nothing and knows no sed.
         for Unit of Files.Name_List'
           [U.To_Unbounded_String ("Sedlib"),
            U.To_Unbounded_String ("Messages"),
            U.To_Unbounded_String ("Terminal_Styles"),
            U.To_Unbounded_String ("Sed.IO"),
            U.To_Unbounded_String ("Sed.Scripts")]
         loop
            Forbid ("sed-command_line", U.To_String (Unit));
         end loop;

         --  Input and output carry bytes; they know nothing about the engine,
         --  the catalogue or styling, which is what lets the execution
         --  adapters be the only thing bridging them to sedlib.
         for Unit of Files.Name_List'
           [U.To_Unbounded_String ("Sedlib"),
            U.To_Unbounded_String ("Messages"),
            U.To_Unbounded_String ("Terminal_Styles")]
         loop
            Forbid ("sed-input", U.To_String (Unit));
            Forbid ("sed-output", U.To_String (Unit));
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

      --  A template may only name arguments its diagnostic actually supplies.
      --
      --  A placeholder the code never sets renders as nothing, so the message
      --  silently loses the detail it was written to carry. This is the check
      --  that makes the parameter schema mean something at the text end as
      --  well as at the Ada end.
      declare
         --  Catalogue argument name for each parameter. Mirrors the mapping
         --  in Sed.Diagnostics.Rendering; a divergence shows up here as a
         --  template naming an argument no code can supply.
         function Argument_Name
           (Name : Sed.Diagnostics.Parameter_Name) return String
           is (case Name is
                 when Sed.Diagnostics.Path => "path",
                 when Sed.Diagnostics.Option => "option",
                 when Sed.Diagnostics.Value => "value",
                 when Sed.Diagnostics.Detail => "detail",
                 when Sed.Diagnostics.Capability => "capability",
                 when Sed.Diagnostics.Requirement => "requirement",
                 when Sed.Diagnostics.Limit => "limit",
                 when Sed.Diagnostics.Actual => "actual",
                 when Sed.Diagnostics.Allowed => "allowed");

         --  Whether Code accepts the argument spelled Argument.
         function Accepts
           (Code : Sed.Diagnostics.Diagnostic_Code;
            Argument : String) return Boolean
         is
            Accepted : constant Sed.Diagnostics.Parameter_Set :=
              Sed.Diagnostics.Registry.Accepted (Code);
         begin
            for Name in Sed.Diagnostics.Parameter_Name loop
               if Accepted (Name) and then Argument_Name (Name) = Argument then
                  return True;
               end if;
            end loop;

            return False;
         end Accepts;

         Locales : constant Files.Name_List :=
           [U.To_Unbounded_String ("en"), U.To_Unbounded_String ("da")];

         Catalog_Text : constant String := Files.Read_Raw_File (Catalog);

         --  The template recorded for a locale and key, or an empty string.
         --
         --  Read here rather than through a key/value helper: catalogue lines
         --  are written "locale.key = message", and a helper that expects
         --  "key=" finds nothing and silently makes this whole audit pass.
         function Template_For (Locale : String; Key : String) return String is
            Prefix : constant String := Locale & "." & Key & " =";
            First : Positive := Catalog_Text'First;
         begin
            for Index in Catalog_Text'Range loop
               if Catalog_Text (Index) = ASCII.LF or else Index = Catalog_Text'Last
               then
                  declare
                     Stop : constant Natural :=
                       (if Catalog_Text (Index) = ASCII.LF then Index - 1 else Index);
                  begin
                     if Stop - First + 1 > Prefix'Length
                       and then Catalog_Text (First .. First + Prefix'Length - 1)
                                = Prefix
                     then
                        return Catalog_Text (First + Prefix'Length .. Stop);
                     end if;
                  end;

                  First := Index + 1;
               end if;
            end loop;

            return "";
         end Template_For;

      begin
         for Code in Sed.Diagnostics.Diagnostic_Code loop
            declare
               Key : constant String :=
                 Sed.Diagnostics.Registry.Message_Key (Code);
            begin
               for Locale of Locales loop
                  declare
                     Template : constant String :=
                       Template_For (U.To_String (Locale), Key);
                     Index : Natural := Template'First;
                  begin
                     --  A key with no template would make the placeholder
                     --  scan below pass by having nothing to scan.
                     Check
                       (Template'Length > 0,
                        U.To_String (Locale) & "." & Key & " has a template");

                     while Index <= Template'Last loop
                        if Template (Index) = '{' then
                           declare
                              Stop : Natural := Index + 1;
                           begin
                              while Stop <= Template'Last
                                and then Template (Stop) /= '}'
                              loop
                                 Stop := Stop + 1;
                              end loop;

                              if Stop <= Template'Last then
                                 declare
                                    Argument : constant String :=
                                      Template (Index + 1 .. Stop - 1);
                                 begin
                                    Check
                                      (Accepts (Code, Argument),
                                       U.To_String (Locale) & "." & Key
                                       & " names argument {" & Argument
                                       & "}, which the code supplies");
                                 end;
                                 Index := Stop;
                              end if;
                           end;
                        end if;

                        Index := Index + 1;
                     end loop;
                  end;
               end loop;
            end;
         end loop;
      end;

      --  No catalogue key outlives its use.
      --
      --  The checks above run one way: every code and option must have a
      --  message. This runs the other way, so a key whose caller was deleted
      --  or renamed does not sit in the catalogue for a translator to keep
      --  translating for ever.
      declare
         Sources : constant Files.Path_List :=
           Files.List_Tree (Source_Root, "*.ad*");

         --  Whether any production source names this key as a literal.
         function Key_Is_Used (Key : String) return Boolean is
         begin
            for Path of Sources loop
               if Files.File_Contains (U.To_String (Path), """" & Key & """")
               then
                  return True;
               end if;
            end loop;

            return False;
         end Key_Is_Used;

         Catalog_Text : constant String := Files.Read_Raw_File (Catalog);
         First : Positive := Catalog_Text'First;
         Prefix : constant String := "en.";
      begin
         for Index in Catalog_Text'Range loop
            if Catalog_Text (Index) = ASCII.LF then
               declare
                  Line : constant String := Catalog_Text (First .. Index - 1);
               begin
                  if Line'Length > Prefix'Length
                    and then Line (Line'First .. Line'First + Prefix'Length - 1)
                             = Prefix
                  then
                     --  Take the key, which runs to the space before "=".
                     declare
                        Stop : Natural := Line'First + Prefix'Length;
                     begin
                        while Stop <= Line'Last and then Line (Stop) /= ' ' loop
                           Stop := Stop + 1;
                        end loop;

                        declare
                           Key : constant String :=
                             Line (Line'First + Prefix'Length .. Stop - 1);
                        begin
                           Check
                             (Key_Is_Used (Key),
                              "catalogue key " & Key & " is still used");
                        end;
                     end;
                  end if;
               end;

               First := Index + 1;
            end if;
         end loop;
      end;

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

      --  Generated files are build output and must never be committed: a
      --  tracked one goes stale silently and then contradicts the sources it
      --  was generated from.
      declare
         Generated : constant Files.Name_List :=
           [U.To_Unbounded_String ("obj/"),
            U.To_Unbounded_String ("bin/"),
            U.To_Unbounded_String ("lib/"),
            U.To_Unbounded_String ("alire/"),
            U.To_Unbounded_String ("config/"),
            U.To_Unbounded_String ("dist/")];

         Listing : constant String := Files.Join (Root, "dist-tracked.txt");
      begin
         if Processes.Run_Shell_In_Directory
              (Root, "git ls-files > " & Processes.Shell_Quote (Listing)) = 0
         then
            for Prefix of Generated loop
               Check
                 (not Files.File_Contains (Listing, U.To_String (Prefix)),
                  "no tracked file lives under " & U.To_String (Prefix));
            end loop;

            Files.Delete_File_If_Present (Listing);
         end if;
      end;

      Do_Prove;

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

   ---------------
   -- Do_Prove --
   ---------------

   procedure Do_Prove is
      --  Invoked through Alire: the prover needs the same project environment
      --  the build gets, and finds no project without it.
      Launcher : constant String := Processes.Locate_Command ("alr");
      Program : constant String :=
        (if Processes.Locate_Command ("gnatprove")'Length = 0
         then "" else Launcher);
   begin
      if Program'Length = 0 then
         --  Proof is an optional scope: a host without the prover still runs
         --  every other check rather than failing for a missing tool.
         Note ("gnatprove is not installed; skipping the proof scope");
         return;
      end if;

      Note ("proving the declared scope");

      --  Sed.Status is the package worth proving: it is pure logic, and its
      --  contract is the invariant the whole program depends on -- that a
      --  later success can never lower an outcome an earlier failure raised.
      --  The stream and filesystem adapters are deliberately out of scope.
      --
      --  The result is read from the reported messages rather than from the
      --  exit status. gnatprove analyses the whole project even when asked
      --  about one unit, so its status reflects units that carry no SPARK
      --  contracts at all; what matters here is that nothing in the declared
      --  scope is left unproved. With --report=fail a clean scope reports
      --  nothing.
      declare
         Report : constant String := Files.Join (Root, "proof-report.txt");
         Ran : constant Integer :=
           Processes.Run_Shell_In_Directory
             (Root,
              Processes.Shell_Quote (Program) & " exec -- gnatprove"
              & " -P sed.gpr --level=1"
              & " --mode=all -u sed-status.adb -u sed-scripts-layout.adb"
              & " -u sed-input-delivery.adb -u sed-input-cursor.adb"
              & " --report=fail > "
              & Processes.Shell_Quote (Report) & " 2>&1");
         pragma Unreferenced (Ran);

         Output : constant String :=
           (if Files.File_Exists (Report)
            then Files.Read_Raw_File (Report)
            else "");
      begin
         Check
           (Output'Length > 0, "the prover produced a report");
         Check
           (not Occurs (Output, ": medium:")
              and then not Occurs (Output, ": high:")
              and then not Occurs (Output, ": error:"),
            "the proof scope proves: status, source map, delivery and operand walk");

         Files.Delete_File_If_Present (Report);
      end;
   end Do_Prove;

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
      --
      --  Quiet is deliberately off: it would append its own redirection after
      --  the command's, and the last redirection of a stream is the one that
      --  takes effect, so every artefact these pipelines write would be
      --  created empty. The commands below redirect everything themselves.
      function Shell (Command : String) return Integer
        is (Processes.Run_Shell_In_Directory (Root, Command, Quiet => False));

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

         --  Build output must never ship. An absent or empty listing would
         --  make every one of these pass for the wrong reason, so the listing
         --  has to be real before its contents mean anything.
         Check
           (Files.File_Exists (Listing)
              and then Files.Read_Raw_File (Listing)'Length > 0,
            "the archive listing is not empty");

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

      --  Hash from inside the artefact directory so the recorded name is the
      --  simple one a consumer will have, with no path to strip afterwards.
      Check
        (Processes.Run_Shell_In_Directory
           (Dist,
            "sha256sum " & Ada.Directories.Simple_Name (Archive) & " > "
            & Ada.Directories.Simple_Name (Checksums)) = 0,
         "checksums were written");

      --  A zero exit status only says the command ran. What matters is that
      --  the file actually holds a hash.
      declare
         Recorded : constant String :=
           (if Files.File_Exists (Checksums)
            then Files.Read_Raw_File (Checksums)
            else "");
         Digits_Seen : Natural := 0;
      begin
         for Item of Recorded loop
            exit when Item = ' ';

            if Item in '0' .. '9' | 'a' .. 'f' then
               Digits_Seen := Digits_Seen + 1;
            end if;
         end loop;

         Check
           (Digits_Seen = 64,
            "the checksum file records a SHA-256 digest");
         Check
           (Files.File_Contains
              (Checksums, Ada.Directories.Simple_Name (Archive)),
            "the checksum file names the archive");
      end;

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
   elsif Command = "prove" then
      Do_Prove;
   elsif Command = "clean" then
      Do_Clean;
   elsif Command = "release" then
      Do_Release;
   else
      IO.Put_Line
        ("usage: sed_tools build | test | verify | docs | prove | clean"
         & " | release");
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

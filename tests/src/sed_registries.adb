package body Sed_Registries is

   ------------------
   -- Requirements --
   ------------------

   function Requirements return Requirement_Array is
   begin
      return
        [(Id => B ("SED-CLI-001"),
          Summary => B ("POSIX invocation forms, options and operands"),
          Owner => B ("Sed.Command_Line.Options"),
          Tests => B ("CLI-VALID-001 CLI-VALID-002 CLI-VALID-003"
                      & " CLI-VALID-004 CLI-VALID-005 CLI-VALID-006"
                      & " CLI-VALID-007 CLI-VALID-008"),
          Class => Conforming),

         (Id => B ("SED-CLI-002"),
          Summary => B ("Malformed invocations are rejected with status 2"),
          Owner => B ("Sed.Command_Line.Validation"),
          Tests => B ("CLI-ERROR-001 CLI-ERROR-002 CLI-ERROR-003"
                      & " CLI-ERROR-004 CLI-ERROR-005 CLI-ERROR-006"
                      & " CLI-ERROR-007 CLI-STATUS-001 PROC-ERROR-001"),
          Class => Conforming),

         (Id => B ("SED-CLI-003"),
          Summary => B ("GNU options are unknown options, not aliases"),
          Owner => B ("Sed.Command_Line.Options"),
          Tests => B ("CLI-ERROR-008"),
          Class => Unsupported),

         (Id => B ("SED-CLI-004"),
          Summary => B ("Help and version write to standard output and exit 0"),
          Owner => B ("Sed.Help"),
          Tests => B ("CLI-VALID-010 CLI-STATUS-002 PROC-ADMIN-001"),
          Class => Extension),

         (Id => B ("SED-SCRIPT-001"),
          Summary => B ("Script sources keep command-line order and provenance"),
          Owner => B ("Sed.Scripts"),
          Tests => B ("SCRIPT-ORDER-001 SCRIPT-MAP-001 PROC-SCRIPT-001"),
          Class => Conforming),

         (Id => B ("SED-SCRIPT-002"),
          Summary => B ("Sources are newline-separated and never merged"),
          Owner => B ("Sed.Scripts"),
          Tests => B ("SCRIPT-BOUNDARY-001 SCRIPT-BOUNDARY-002"
                      & " SCRIPT-BOUNDARY-003"),
          Class => Conforming),

         (Id => B ("SED-SCRIPT-003"),
          Summary => B ("Compile failures name the source unit, line and column"),
          Owner => B ("Sed.Scripts.Compilation"),
          Tests => B ("SCRIPT-DIAG-001 SCRIPT-DIAG-002 PROC-ERROR-002"),
          Class => Implementation_Defined),

         (Id => B ("SED-SCRIPT-004"),
          Summary => B ("An unreadable script file is fatal before input opens"),
          Owner => B ("Sed.Scripts.Loading"),
          Tests => B ("SCRIPT-LOAD-001 DIAG-CODE-002 PROC-SCRIPT-001"),
          Class => Conforming),

         (Id => B ("SED-INPUT-001"),
          Summary => B ("Operands form one logical stream with continuous"
                        & " numbering and a single final line"),
          Owner => B ("Sed.Input.Logical_Stream"),
          Tests => B ("INPUT-001 INPUT-002 PROC-INPUT-001"),
          Class => Conforming),

         (Id => B ("SED-INPUT-002"),
          Summary => B ("A final line without a newline round-trips exactly"),
          Owner => B ("Sed.Output.Standard"),
          Tests => B ("INPUT-003 PROC-INPUT-003"),
          Class => Implementation_Defined),

         (Id => B ("SED-INPUT-003"),
          Summary => B ("An unreadable operand is recoverable"),
          Owner => B ("Sed.Input.Logical_Stream"),
          Tests => B ("FAIL-INPUT-001 FAIL-INPUT-002 PROC-INPUT-002"),
          Class => Implementation_Defined),

         (Id => B ("SED-OUTPUT-001"),
          Summary => B ("Standard output carries only program data"),
          Owner => B ("Sed.Output.Standard"),
          Tests => B ("OUTPUT-001 STYLE-002 CLI-STATUS-001 PROC-STYLE-001"),
          Class => Conforming),

         (Id => B ("SED-OUTPUT-002"),
          Summary => B ("Write destinations are created after compilation,"
                        & " exactly once each"),
          Owner => B ("Sed.Output.Named_Files"),
          Tests => B ("SCRIPT-WRITE-001 SCRIPT-WRITE-002 SCRIPT-WRITE-003"
                      & " PROC-FILE-002"),
          Class => Conforming),

         (Id => B ("SED-DIAG-001"),
          Summary => B ("Every diagnostic has one registry descriptor and a"
                        & " satisfied parameter schema"),
          Owner => B ("Sed.Diagnostics.Registry"),
          Tests => B ("DIAG-REGISTRY-001 DIAG-SCHEMA-001"),
          Class => Implementation_Defined),

         (Id => B ("SED-DIAG-002"),
          Summary => B ("Untrusted values cannot inject terminal escapes"),
          Owner => B ("Sed.Diagnostics.Quoting"),
          Tests => B ("DIAG-ESCAPE-001 DIAG-ESCAPE-002"),
          Class => Implementation_Defined),

         (Id => B ("SED-DIAG-003"),
          Summary => B ("Engine conditions map to the intended sed codes"),
          Owner => B ("Sed.Engine"),
          Tests => B ("DIAG-MAPPING-001 DIAG-CODE-001 DIAG-CODE-003"
                      & " DIAG-CODE-004"),
          Class => Implementation_Defined),

         (Id => B ("SED-LOCALE-001"),
          Summary => B ("Every user-facing string comes from the catalogue,"
                        & " and program data never does"),
          Owner => B ("Sed.Localization"),
          Tests => B ("LOCALE-001 LOCALE-002 PROC-LOCALE-001"),
          Class => Implementation_Defined),

         (Id => B ("SED-STYLE-001"),
          Summary => B ("Styling changes bytes but never information"),
          Owner => B ("Sed.Terminal"),
          Tests => B ("STYLE-001 STYLE-002 PROC-STYLE-001"),
          Class => Extension),

         (Id => B ("SED-STATUS-001"),
          Summary => B ("Statuses accumulate monotonically to a stable code"),
          Owner => B ("Sed.Status"),
          Tests => B ("STATUS-001 PROC-STATUS-001"),
          Class => Implementation_Defined),

         (Id => B ("SED-POSIX-RE-001"),
          Summary => B ("Expressions are POSIX basic regular expressions"),
          Owner => B ("Sed.Scripts.Compilation"),
          Tests => B ("SUB-002 SUB-003"),
          Class => Conforming),

         (Id => B ("SED-TOOL-001"),
          Summary => B ("All tooling is Ada and every build runs through Alire"),
          Owner => B ("sed_tools"),
          Tests => B ("TOOL-REGISTRY-001"),
          Class => Implementation_Defined)];
   end Requirements;

   --------------
   -- Commands --
   --------------

   function Commands return Command_Array is

      --  Every POSIX command, described once. Address arity and the cycle,
      --  output and file columns are documentation of what each command can
      --  do, not a parser: sedlib owns the sed language.
      function Row
        (Symbol : Character;
         Addresses : Natural;
         Operand : Boolean;
         Cycle : Boolean;
         Output : Boolean;
         Files : Boolean;
         Tests : String) return Command_Descriptor
        is ((Symbol => Symbol,
             Max_Addresses => Addresses,
             Takes_Operand => Operand,
             Alters_Cycle => Cycle,
             Writes_Output => Output,
             Uses_Files => Files,
             Posix_Required => True,
             Tests => B (Tests)));

   begin
      return
        [Row ('p', 2, False, False, True, False, "CMD-PRINT-001"),
         Row ('P', 2, False, False, True, False, "CMD-PRINT-001"),
         Row ('=', 2, False, False, True, False, "CMD-PRINT-001 OUTPUT-001"),
         Row ('l', 2, False, False, True, False, "CMD-PRINT-001"),
         Row ('d', 2, False, True, False, False, "CMD-DELETE-001"),
         Row ('D', 2, False, True, False, False, "CMD-PRINT-001"),
         Row ('q', 1, False, True, False, False, "CMD-DELETE-001"),
         Row ('h', 2, False, False, False, False, "CMD-HOLD-001"),
         Row ('H', 2, False, False, False, False, "CMD-HOLD-001"),
         Row ('g', 2, False, False, False, False, "CMD-HOLD-001"),
         Row ('G', 2, False, False, False, False, "CMD-HOLD-001"),
         Row ('x', 2, False, False, False, False, "CMD-HOLD-001"),
         Row ('n', 2, False, True, True, False, "CMD-CYCLE-001"),
         Row ('N', 2, False, True, False, False, "CMD-CYCLE-001 SUB-002"),
         Row ('a', 1, True, False, True, False, "CMD-TEXT-001"),
         Row ('i', 1, True, False, True, False, "CMD-TEXT-001"),
         Row ('c', 2, True, True, True, False, "CMD-TEXT-001"),
         Row (':', 0, True, False, False, False, "CMD-BRANCH-001"),
         Row ('b', 2, True, True, False, False, "CMD-BRANCH-001"),
         Row ('t', 2, True, True, False, False, "CMD-BRANCH-001"),
         Row ('y', 2, True, False, False, False, "CMD-TRANSLIT-001"),
         Row ('r', 1, True, False, True, True, "FILE-001 PROC-FILE-001"),
         Row ('w', 2, True, False, False, True, "FILE-002 PROC-FILE-001"),
         Row ('s', 2, True, False, True, True, "SUB-001 SUB-002 SUB-003"),
         Row ('{', 2, False, False, False, False, "CMD-GROUP-001"),
         Row ('}', 0, False, False, False, False, "CMD-GROUP-001"),
         Row ('#', 0, True, False, False, False, "CMD-GROUP-001")];
   end Commands;

end Sed_Registries;

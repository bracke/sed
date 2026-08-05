with Ada.Strings.Bounded;
with Sed.Diagnostics;

--  Authoritative traceability registries.
--
--  These tables are the link between what the project claims and what it
--  proves. "sed_tools verify" reads them and fails when a claim has no test,
--  or names a test that does not exist, so a requirement cannot quietly lose
--  its coverage and a table cannot drift into citing something that was
--  renamed or deleted.
--
--  They live in the test crate because they exist to check the project rather
--  than to run it: nothing in the production closure depends on them.
--
--  Diagnostic_Coverage is indexed by the diagnostic code type itself, so
--  adding a code makes this file fail to compile until the code is given a
--  test. That is the strongest of the three checks, because it cannot be
--  forgotten rather than merely being reported.
package Sed_Registries is

   Max_Length : constant := 400;

   package Text is new Ada.Strings.Bounded.Generic_Bounded_Length (Max_Length);

   --  How a feature stands against POSIX, matching doc/posix-conformance.md.
   type Conformance_Class is
     (Conforming,
      Implementation_Defined,
      Extension,
      Unsupported);

   --  One requirement, its owner and the tests that hold it up.
   type Requirement is record
      --  Stable identifier, for example "SED-CLI-001".
      Id : Text.Bounded_String;
      Summary : Text.Bounded_String;
      --  Package that implements it.
      Owner : Text.Bounded_String;
      --  Space-separated test identifiers.
      Tests : Text.Bounded_String;
      Class : Conformance_Class;
   end record;

   type Requirement_Array is array (Positive range <>) of Requirement;

   --  @return Every requirement the project claims to meet.
   function Requirements return Requirement_Array;

   --  One sed command, described for documentation and coverage rather than
   --  for parsing: the compiler is sedlib's, not this project's.
   type Command_Descriptor is record
      Symbol : Character;
      --  Addresses the command accepts, 0 to 2.
      Max_Addresses : Natural;
      Takes_Operand : Boolean;
      --  Whether the command can end or restart the cycle.
      Alters_Cycle : Boolean;
      Writes_Output : Boolean;
      Uses_Files : Boolean;
      Posix_Required : Boolean;
      Tests : Text.Bounded_String;
   end record;

   type Command_Array is array (Positive range <>) of Command_Descriptor;

   --  @return Every sed command this program supports.
   function Commands return Command_Array;

   --  What covers a diagnostic code, and why when it is not behavioural.
   type Coverage is record
      --  Space-separated test identifiers.
      Tests : Text.Bounded_String;
      --  Present only where the code cannot be provoked through the command
      --  line with the resolved engine, explaining what is tested instead.
      Note : Text.Bounded_String;
   end record;

   type Coverage_Table is
     array (Sed.Diagnostics.Diagnostic_Code) of Coverage;

   --  Indexed by the code type, so a new code cannot be added without being
   --  given coverage here.
   Diagnostic_Coverage : constant Coverage_Table;

private

   --  Shorthand for the table entries below.
   function B (Value : String) return Text.Bounded_String
     is (Text.To_Bounded_String (Value));

   Diagnostic_Coverage : constant Coverage_Table :=
       [Sed.Diagnostics.Unknown_Option =>
          (B ("CLI-ERROR-004 CLI-ERROR-005 CLI-STATUS-001 PROC-ERROR-001"), B ("")),
        Sed.Diagnostics.Missing_Option_Argument =>
          (B ("CLI-ERROR-002 CLI-ERROR-003 CLI-ERROR-006 PROC-ERROR-001"), B ("")),
        Sed.Diagnostics.Invalid_Option_Argument =>
          (B ("CLI-ERROR-007"), B ("")),
        Sed.Diagnostics.Missing_Script =>
          (B ("CLI-ERROR-001 PROC-ERROR-001"), B ("")),
        Sed.Diagnostics.Script_File_Open_Failed =>
          (B ("SCRIPT-LOAD-001 PROC-SCRIPT-001"), B ("")),
        Sed.Diagnostics.Script_File_Read_Failed =>
          (B ("DIAG-CODE-002"), B ("")),
        Sed.Diagnostics.Script_Syntax_Error =>
          (B ("SCRIPT-DIAG-001 PROC-ERROR-002"), B ("")),
        Sed.Diagnostics.Invalid_Regular_Expression =>
          (B ("SCRIPT-DIAG-002 PROC-ERROR-002"), B ("")),
        Sed.Diagnostics.Undefined_Label =>
          (B ("DIAG-CODE-001 DIAG-MAPPING-001"), B ("")),
        Sed.Diagnostics.Duplicate_Label =>
          (B ("DIAG-CODE-001"), B ("")),
        Sed.Diagnostics.Input_Open_Failed =>
          (B ("FAIL-INPUT-001 PROC-INPUT-002"), B ("")),
        Sed.Diagnostics.Input_Read_Failed =>
          (B ("FAIL-INPUT-002"), B ("")),
        Sed.Diagnostics.Standard_Output_Failed =>
          (B ("FAIL-OUTPUT-001"), B ("")),
        Sed.Diagnostics.Named_Output_Open_Failed =>
          (B ("FAIL-OUTPUT-002"), B ("")),
        Sed.Diagnostics.Named_Output_Write_Failed =>
          (B ("FAIL-OUTPUT-003"), B ("")),
        Sed.Diagnostics.Read_Resource_Failed =>
          (B ("DIAG-CODE-003"), B ("")),
        Sed.Diagnostics.Execution_Failed =>
          (B ("DIAG-MAPPING-001"),
           B ("The engine reports Program_Not_Executable only behind a"
              & " precondition that execution already guarantees, and"
              & " Cancelled only when a cancellation source is supplied,"
              & " which this program does not do. The mapping is tested"
              & " directly instead.")),
        Sed.Diagnostics.Resource_Exhausted =>
          (B ("DIAG-CODE-004 DIAG-MAPPING-001"), B ("")),
        Sed.Diagnostics.Missing_Library_Capability =>
          (B ("DIAG-MAPPING-001"),
           B ("Unsupported_Command is the engine's own guard for a command"
              & " with no compiler mapping, which the resolved version never"
              & " reports. The code is kept so that an engine which did"
              & " report it would not have the fault reclassified as a user"
              & " script error, and the mapping is tested directly.")),
        Sed.Diagnostics.Internal_Error =>
          (B ("DIAG-REGISTRY-001"),
           B ("Raised only by the outermost handler for a failure every"
              & " lower layer already converts, so it is covered"
              & " structurally through the registry rather than by"
              & " provoking an unexpected exception."))];

end Sed_Registries;

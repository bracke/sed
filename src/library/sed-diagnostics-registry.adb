package body Sed.Diagnostics.Registry is

   use Message_Keys;

   --  Detail is accepted by every code as an optional technical annotation.
   Detail_Only : constant Parameter_Set := [Detail => True, others => False];

   --  Build one descriptor. Keeping this local keeps the table below readable
   --  while still producing a single constant aggregate.
   function Entry_For
     (Key            : String;
      Severity       : Diagnostics.Severity;
      Recoverability : Diagnostics.Recoverability;
      Status_Effect  : Sed.Status.Outcome;
      Owner          : Subsystem;
      Required       : Parameter_Set := No_Parameters;
      Optional       : Parameter_Set := Detail_Only) return Code_Descriptor;

   ---------------
   -- Entry_For --
   ---------------

   function Entry_For
     (Key            : String;
      Severity       : Diagnostics.Severity;
      Recoverability : Diagnostics.Recoverability;
      Status_Effect  : Sed.Status.Outcome;
      Owner          : Subsystem;
      Required       : Parameter_Set := No_Parameters;
      Optional       : Parameter_Set := Detail_Only) return Code_Descriptor is
   begin
      return
        (Key            => To_Bounded_String (Key),
         Severity       => Severity,
         Recoverability => Recoverability,
         Status_Effect  => Status_Effect,
         Owner          => Owner,
         Required       => Required,
         Optional       => Optional);
   end Entry_For;

   --  The authoritative table. Adding a code without adding a row here is a
   --  compile-time error because the aggregate must cover the whole type.
   Table : constant array (Diagnostic_Code) of Code_Descriptor :=
     [Unknown_Option =>
        Entry_For
          (Key            => "sed.error.option.unknown",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Invocation_Failure,
           Owner          => Command_Line_Subsystem,
           Required       => [Option => True, others => False]),

      Missing_Option_Argument =>
        Entry_For
          (Key            => "sed.error.option.missing_argument",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Invocation_Failure,
           Owner          => Command_Line_Subsystem,
           Required       => [Option => True, others => False]),

      Invalid_Option_Argument =>
        Entry_For
          (Key            => "sed.error.option.invalid_argument",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Invocation_Failure,
           Owner          => Command_Line_Subsystem,
           Required       => [Option => True, Value => True, others => False]),

      Missing_Script =>
        Entry_For
          (Key            => "sed.error.script.missing",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Invocation_Failure,
           Owner          => Command_Line_Subsystem),

      Script_File_Open_Failed =>
        Entry_For
          (Key            => "sed.error.script.open_failed",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Scripts_Subsystem,
           Required       => [Path => True, others => False]),

      Script_File_Read_Failed =>
        Entry_For
          (Key            => "sed.error.script.read_failed",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Scripts_Subsystem,
           Required       => [Path => True, others => False]),

      Script_Syntax_Error =>
        Entry_For
          (Key            => "sed.error.script.syntax",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Scripts_Subsystem,
           Optional       => [Detail => True, Value => True, others => False]),

      Invalid_Regular_Expression =>
        Entry_For
          (Key            => "sed.error.regexp.invalid",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Scripts_Subsystem,
           Optional       => [Detail => True, Value => True, others => False]),

      Undefined_Label =>
        Entry_For
          (Key            => "sed.error.script.undefined_label",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Scripts_Subsystem,
           Optional       => [Detail => True, Value => True, others => False]),

      Duplicate_Label =>
        Entry_For
          (Key            => "sed.error.script.duplicate_label",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Scripts_Subsystem,
           Optional       => [Detail => True, Value => True, others => False]),

      Input_Open_Failed =>
        Entry_For
          (Key            => "sed.error.input.open_failed",
           Severity       => Error,
           --  A missing operand does not stop later operands being processed.
           Recoverability => Recoverable,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Input_Subsystem,
           Required       => [Path => True, others => False]),

      Input_Read_Failed =>
        Entry_For
          (Key            => "sed.error.input.read_failed",
           Severity       => Error,
           Recoverability => Recoverable,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Input_Subsystem,
           Required       => [Path => True, others => False]),

      Standard_Output_Failed =>
        Entry_For
          (Key            => "sed.error.output.standard_failed",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Output_Subsystem),

      Named_Output_Open_Failed =>
        Entry_For
          (Key            => "sed.error.output.open_failed",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Output_Subsystem,
           Required       => [Path => True, others => False]),

      Named_Output_Write_Failed =>
        Entry_For
          (Key            => "sed.error.output.write_failed",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Output_Subsystem,
           Required       => [Path => True, others => False]),

      Read_Resource_Failed =>
        Entry_For
          (Key            => "sed.warning.resource.read_failed",
           --  POSIX treats an rfile that does not exist or cannot be opened as
           --  an empty file with no error condition, and sed implements that
           --  silently. This warning covers only a host read fault reported
           --  after the file was opened successfully: output is then
           --  incomplete, but POSIX defines no error status for it.
           Severity       => Warning,
           Recoverability => Recoverable,
           Status_Effect  => Sed.Status.Success,
           Owner          => Execution_Subsystem,
           Required       => [Path => True, others => False]),

      Execution_Failed =>
        Entry_For
          (Key            => "sed.error.runtime.execution_failed",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Execution_Subsystem,
           Optional       => [Detail => True, Value => True, others => False]),

      Resource_Exhausted =>
        Entry_For
          (Key            => "sed.error.runtime.resource_exhausted",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Execution_Subsystem,
           Optional       =>
             [Detail  => True,
              Limit   => True,
              Actual  => True,
              Allowed => True,
              others  => False]),

      Missing_Library_Capability =>
        Entry_For
          (Key            => "sed.error.runtime.missing_capability",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Processing_Failure,
           Owner          => Environment_Subsystem,
           Required       => [Capability => True, others => False],
           Optional       => [Detail => True, Requirement => True, others => False]),

      Internal_Error =>
        Entry_For
          (Key            => "sed.error.internal.unexpected",
           Severity       => Error,
           Recoverability => Fatal,
           Status_Effect  => Sed.Status.Internal_Failure,
           Owner          => Internal_Subsystem)];

   ----------------
   -- Descriptor --
   ----------------

   function Descriptor (Code : Diagnostic_Code) return Code_Descriptor is
   begin
      return Table (Code);
   end Descriptor;

   -----------------
   -- Message_Key --
   -----------------

   function Message_Key (Code : Diagnostic_Code) return String is
   begin
      return To_String (Table (Code).Key);
   end Message_Key;

   --------------
   -- Accepted --
   --------------

   function Accepted (Code : Diagnostic_Code) return Parameter_Set is
      Result : Parameter_Set := No_Parameters;
   begin
      for Name in Parameter_Name loop
         Result (Name) :=
           Table (Code).Required (Name) or else Table (Code).Optional (Name);
      end loop;
      return Result;
   end Accepted;

end Sed.Diagnostics.Registry;

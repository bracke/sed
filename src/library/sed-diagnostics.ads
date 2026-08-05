private with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Sed.Status;

--  Structured diagnostics produced by every sed subsystem.
--
--  A diagnostic is data, not presentation: it carries a stable code, a
--  severity, a recoverability, the process-status effect, an optional source
--  location, an optional related location and a typed parameter set. Nothing
--  in this package knows about message catalogues or terminal styling, so
--  diagnostics can be asserted structurally in tests independently of any
--  locale.
--
--  Rendering lives in Sed.Diagnostics.Rendering; the authoritative code
--  descriptors live in Sed.Diagnostics.Registry.
package Sed.Diagnostics is

   package U renames Ada.Strings.Unbounded;

   --  Stable diagnostic codes.
   --
   --  Every code has exactly one descriptor in Sed.Diagnostics.Registry and at
   --  least one test. Codes are never reused for a different meaning.
   type Diagnostic_Code is
     (
      --  Invocation
      Unknown_Option,
      Missing_Option_Argument,
      Invalid_Option_Argument,
      Missing_Script,
      --  Script loading and compilation
      Script_File_Open_Failed,
      Script_File_Read_Failed,
      Script_Syntax_Error,
      Invalid_Regular_Expression,
      Undefined_Label,
      Duplicate_Label,
      --  Input
      Input_Open_Failed,
      Input_Read_Failed,
      --  Output
      Standard_Output_Failed,
      Named_Output_Open_Failed,
      Named_Output_Write_Failed,
      Read_Resource_Failed,
      --  Execution and environment
      Execution_Failed,
      Resource_Exhausted,
      Missing_Library_Capability,
      Internal_Error);

   --  Diagnostic severity.
   type Severity is (Information, Warning, Error);

   --  Whether processing may continue after the diagnostic.
   type Recoverability is (Recoverable, Fatal);

   --  Subsystem responsible for a diagnostic.
   type Subsystem is
     (Command_Line_Subsystem,
      Scripts_Subsystem,
      Input_Subsystem,
      Output_Subsystem,
      Execution_Subsystem,
      Environment_Subsystem,
      Internal_Subsystem);

   --  Kinds of source location a diagnostic can carry.
   type Location_Kind is
     (No_Location,
      --  A filesystem path or input operand name.
      Path_Location,
      --  An inline script supplied with -e; Occurrence is its 1-based index.
      Expression_Location);

   type Source_Location is record
      Kind       : Location_Kind := No_Location;
      Path       : U.Unbounded_String := U.Null_Unbounded_String;
      Occurrence : Natural := 0;
      --  Zero means the corresponding coordinate is unknown.
      Line       : Line_Number := 0;
      Column     : Line_Number := 0;
   end record;

   No_Location_Value : constant Source_Location :=
     (Kind       => No_Location,
      Path       => U.Null_Unbounded_String,
      Occurrence => 0,
      Line       => 0,
      Column     => 0);

   --  Return a location naming a filesystem path or input operand.
   --
   --  @param Path Raw path exactly as supplied by the caller.
   --  @param Line Source line, or zero when unknown.
   --  @param Column Source column, or zero when unknown.
   --  @return Path location value.
   function Path_At
     (Path   : String;
      Line   : Line_Number := 0;
      Column : Line_Number := 0) return Source_Location
     with Post => Path_At'Result.Kind = Path_Location;

   --  Return a location naming an inline -e expression.
   --
   --  @param Occurrence 1-based index of the -e expression.
   --  @param Line Source line within that expression, or zero when unknown.
   --  @param Column Source column, or zero when unknown.
   --  @return Expression location value.
   function Expression_At
     (Occurrence : Positive;
      Line       : Line_Number := 0;
      Column     : Line_Number := 0) return Source_Location
     with Post => Expression_At'Result.Kind = Expression_Location;

   --  Typed diagnostic parameters.
   --
   --  Text parameters carry untrusted values and are escaped by the renderer.
   --  Integer parameters are formatted by the message catalogue so that digit
   --  shapes follow the active locale.
   type Parameter_Name is
     (
      --  Text parameters
      Path,       --  Filesystem path or input operand name
      Option,       --  Option spelling exactly as written on the command line
      Value,        --  Offending value: option argument, label, expression
      Detail,       --  Technical detail supplied by the reporting subsystem
      Capability,   --  sedlib capability identifier
      Requirement,  --  Minimum required dependency version
      Limit,        --  Limit identifier
      --  Integer parameters
      Actual,       --  Observed count
      Allowed);     --  Permitted count

   subtype Text_Parameter is Parameter_Name range Path .. Limit;
   subtype Integer_Parameter is Parameter_Name range Actual .. Allowed;

   type Parameter_Set is array (Parameter_Name) of Boolean
     with Default_Component_Value => False;

   No_Parameters : constant Parameter_Set := [others => False];

   type Diagnostic is private;

   --  Build a diagnostic from its code.
   --
   --  Severity, recoverability, status effect and owning subsystem are taken
   --  from the authoritative registry, so callers cannot invent alternative
   --  policies for a code.
   --
   --  @param Code Stable diagnostic code.
   --  @param Location Primary source location.
   --  @param Related Optional secondary source location.
   --  @return Diagnostic with registry-derived policy and no parameters.
   function Make
     (Code     : Diagnostic_Code;
      Location : Source_Location := No_Location_Value;
      Related  : Source_Location := No_Location_Value) return Diagnostic
     with Post =>
       Diagnostics.Code (Make'Result) = Code
       and then Present (Make'Result) = No_Parameters;

   --  Attach a text parameter.
   --
   --  @param Item Diagnostic to update.
   --  @param Name Text parameter to set.
   --  @param Text Raw, unescaped value.
   procedure Set
     (Item : in out Diagnostic;
      Name : Text_Parameter;
      Text : String)
     with Post => Present (Item) (Name) and then Text_Of (Item, Name) = Text;

   --  Attach an integer parameter.
   --
   --  @param Item Diagnostic to update.
   --  @param Name Integer parameter to set.
   --  @param Number Value to report.
   procedure Set
     (Item   : in out Diagnostic;
      Name   : Integer_Parameter;
      Number : Line_Count)
     with Post => Present (Item) (Name) and then Number_Of (Item, Name) = Number;

   --  @param Item Diagnostic to inspect.
   --  @return Stable diagnostic code.
   function Code (Item : Diagnostic) return Diagnostic_Code;

   --  @param Item Diagnostic to inspect.
   --  @return Severity taken from the registry.
   function Severity_Of (Item : Diagnostic) return Severity;

   --  @param Item Diagnostic to inspect.
   --  @return Recoverability taken from the registry.
   function Recoverability_Of (Item : Diagnostic) return Recoverability;

   --  @param Item Diagnostic to inspect.
   --  @return Subsystem that owns the code.
   function Subsystem_Of (Item : Diagnostic) return Subsystem;

   --  @param Item Diagnostic to inspect.
   --  @return Process-status effect of the code.
   function Status_Effect (Item : Diagnostic) return Sed.Status.Outcome;

   --  @param Item Diagnostic to inspect.
   --  @return Primary source location.
   function Location_Of (Item : Diagnostic) return Source_Location;

   --  @param Item Diagnostic to inspect.
   --  @return Related source location, or No_Location_Value.
   function Related_Of (Item : Diagnostic) return Source_Location;

   --  @param Item Diagnostic to inspect.
   --  @return Set of parameters that have been supplied.
   function Present (Item : Diagnostic) return Parameter_Set;

   --  @param Item Diagnostic to inspect.
   --  @param Name Text parameter to read.
   --  @return Raw, unescaped parameter value; empty when absent.
   function Text_Of (Item : Diagnostic; Name : Text_Parameter) return String;

   --  @param Item Diagnostic to inspect.
   --  @param Name Integer parameter to read.
   --  @return Parameter value; zero when absent.
   function Number_Of (Item : Diagnostic; Name : Integer_Parameter) return Line_Count;

   --  Whether every parameter required by the registry has been supplied.
   --
   --  @param Item Diagnostic to inspect.
   --  @return True when the parameter schema is satisfied.
   function Schema_Satisfied (Item : Diagnostic) return Boolean;

   type Diagnostic_List is private;

   Empty_List : constant Diagnostic_List;

   --  @param List List to update.
   --  @param Item Diagnostic to append.
   procedure Append (List : in out Diagnostic_List; Item : Diagnostic)
     with Post => Length (List) = Length (List)'Old + 1;

   --  Append unless an identical diagnostic is already present.
   --
   --  The engine can report the same fault from more than one place while
   --  recovering, and the user should see one line per distinct problem.
   --  Diagnostics differing in location or in any parameter are kept.
   --
   --  @param List List to update.
   --  @param Item Diagnostic to append.
   procedure Append_Unique (List : in out Diagnostic_List; Item : Diagnostic)
     with Post => Length (List) in Length (List)'Old .. Length (List)'Old + 1;

   --  @param List List to inspect.
   --  @param Item Diagnostic to look for.
   --  @return True when an identical diagnostic is already present.
   function Contains (List : Diagnostic_List; Item : Diagnostic) return Boolean;

   --  @param List List to inspect.
   --  @return Number of diagnostics held.
   function Length (List : Diagnostic_List) return Natural;

   --  @param List List to inspect.
   --  @param Index 1-based position.
   --  @return Diagnostic at that position.
   function Element (List : Diagnostic_List; Index : Positive) return Diagnostic
     with Pre => Index <= Length (List);

   --  @param List List to inspect.
   --  @return True when any element has Error severity.
   function Has_Errors (List : Diagnostic_List) return Boolean;

   --  The aggregate status effect of every diagnostic in the list.
   --
   --  @param List List to inspect.
   --  @return Highest-precedence status effect, or Success when empty.
   function Status_Effect (List : Diagnostic_List) return Sed.Status.Outcome;

private

   type Text_Values is array (Text_Parameter) of U.Unbounded_String;
   type Number_Values is array (Integer_Parameter) of Line_Count;

   type Diagnostic is record
      Code_Value : Diagnostic_Code := Internal_Error;
      Location   : Source_Location := No_Location_Value;
      Related    : Source_Location := No_Location_Value;
      Supplied   : Parameter_Set := No_Parameters;
      Texts      : Text_Values := [others => U.Null_Unbounded_String];
      Numbers    : Number_Values := [others => 0];
   end record;

   package Diagnostic_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Diagnostic);

   type Diagnostic_List is record
      Items : Diagnostic_Vectors.Vector := Diagnostic_Vectors.Empty_Vector;
   end record;

   Empty_List : constant Diagnostic_List :=
     (Items => Diagnostic_Vectors.Empty_Vector);

end Sed.Diagnostics;

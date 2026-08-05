with Ada.Strings.Bounded;

--  Authoritative descriptor table for every diagnostic code.
--
--  Exactly one descriptor exists per code. Severity, recoverability, process
--  status effect, owning subsystem, message key and parameter schema are read
--  from here and nowhere else, so no subsystem can invent a competing policy
--  for a code it reports.
package Sed.Diagnostics.Registry is

   Max_Key_Length : constant := 64;

   package Message_Keys is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max_Key_Length);

   type Code_Descriptor is record
      --  Stable message catalogue key for the primary template.
      Key            : Message_Keys.Bounded_String;
      Severity       : Diagnostics.Severity;
      Recoverability : Diagnostics.Recoverability;
      Status_Effect  : Sed.Status.Outcome;
      Owner          : Subsystem;
      --  Parameters the reporting subsystem must supply.
      Required       : Parameter_Set;
      --  Further parameters the code accepts.
      Optional       : Parameter_Set;
   end record;

   --  @param Code Diagnostic code to describe.
   --  @return The single authoritative descriptor for that code.
   function Descriptor (Code : Diagnostic_Code) return Code_Descriptor;

   --  @param Code Diagnostic code to describe.
   --  @return Message catalogue key of the primary template.
   function Message_Key (Code : Diagnostic_Code) return String
     with Post => Message_Key'Result'Length in 1 .. Max_Key_Length;

   --  @param Code Diagnostic code to describe.
   --  @return Parameters the code accepts, required or optional.
   function Accepted (Code : Diagnostic_Code) return Parameter_Set;

end Sed.Diagnostics.Registry;

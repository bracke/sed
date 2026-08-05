with Sedlib.Text;
with Sed.Diagnostics.Registry;

package body Sed.Engine is

   package D renames Sed.Diagnostics;
   package E renames Sedlib.Diagnostics;

   use type E.Limit_Kind;
   use type D.Diagnostic_Code;

   -------------
   -- Code_Of --
   -------------

   function Code_Of
     (Code : E.Diagnostic_Code) return D.Diagnostic_Code is
   begin
      return
        (case Code is
           --  Regular-expression problems, whether in an address or in the
           --  left-hand side of a substitution.
           when E.Invalid_Expression
              | E.Unterminated_Expression
              | E.Missing_Previous_Expression
              | E.Invalid_Capture_Reference
              | E.Regexp_Execution_Failed =>
             D.Invalid_Regular_Expression,

           when E.Undefined_Label => D.Undefined_Label,
           when E.Duplicate_Label => D.Duplicate_Label,

           --  The engine knows the command but does not implement it. That is
           --  a capability gap in the resolved sedlib, not a user mistake.
           when E.Unsupported_Command => D.Missing_Library_Capability,

           --  Every finite bound the engine enforces.
           when E.Pattern_Space_Limit_Exceeded
              | E.Hold_Space_Limit_Exceeded
              | E.Input_Record_Limit_Exceeded
              | E.Output_Limit_Exceeded
              | E.Pending_Output_Limit_Exceeded
              | E.Instruction_Limit_Exceeded
              | E.Branch_Limit_Exceeded
              | E.Regexp_Match_Limit_Exceeded
              | E.Allocation_Limit_Exceeded
              | E.Compilation_Diagnostic_Limit_Reached
              | E.Numeric_Overflow =>
             D.Resource_Exhausted,

           when E.Input_Read_Failed => D.Input_Read_Failed,
           when E.Output_Write_Failed => D.Standard_Output_Failed,

           when E.Resource_Read_Failed => D.Read_Resource_Failed,
           when E.Resource_Write_Failed => D.Named_Output_Write_Failed,
           when E.Resource_Provider_Missing => D.Missing_Library_Capability,

           when E.Internal_Invariant_Failure => D.Internal_Error,

           when E.Program_Not_Executable | E.Cancelled => D.Execution_Failed,

           --  Everything else is a script the engine could not accept:
           --  unknown commands, malformed addresses, bad substitution or
           --  transliteration syntax, unbalanced groups, and extensions that
           --  the portable language mode correctly refuses.
           when others => D.Script_Syntax_Error);
   end Code_Of;

   -------------------
   -- Is_Reportable --
   -------------------

   function Is_Reportable (Item : E.Diagnostic) return Boolean is
      use type E.Severity;
   begin
      return Item.Severity = E.Error;
   end Is_Reportable;

   ---------------
   -- Translate --
   ---------------

   function Translate
     (Item : E.Diagnostic;
      Location : D.Source_Location := D.No_Location_Value) return D.Diagnostic
   is
      Code : constant D.Diagnostic_Code := Code_Of (Item.Code);
      Result : D.Diagnostic := D.Make (Code, Location);
      Accepted : constant D.Parameter_Set := D.Registry.Accepted (Code);

      Related : constant String := Sedlib.Text.To_String (Item.Related_Value);
      Detail : constant String := Sedlib.Text.To_String (Item.Detail);
   begin
      if Accepted (D.Detail) then
         --  The engine identifier is a stable, documented token such as
         --  "unknown_command"; it names a condition, not an implementation.
         D.Set (Result, D.Detail,
                (if Detail'Length > 0
                 then E.Identifier (Item.Code) & ": " & Detail
                 else E.Identifier (Item.Code)));
      end if;

      if Related'Length > 0 and then Accepted (D.Value) then
         D.Set (Result, D.Value, Related);
      end if;

      if Code = D.Missing_Library_Capability then
         D.Set (Result, D.Capability, E.Identifier (Item.Code));
      end if;

      declare
         Source_Name : constant String := Sedlib.Text.To_String (Item.Source_Name);
      begin
         if Source_Name'Length > 0
           and then Accepted (D.Path)
           and then not D.Present (Result) (D.Path)
         then
            D.Set (Result, D.Path, Source_Name);
         end if;
      end;

      if Item.Limit /= E.No_Limit and then Accepted (D.Limit) then
         D.Set (Result, D.Limit, E.Limit_Kind'Image (Item.Limit));
         D.Set (Result, D.Actual, Line_Count (Item.Actual));
         D.Set (Result, D.Allowed, Line_Count (Item.Allowed));
      end if;

      return Result;
   end Translate;

end Sed.Engine;

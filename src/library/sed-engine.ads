with Sedlib.Diagnostics;
with Sed.Diagnostics;

--  Translation of sedlib diagnostics into sed diagnostics.
--
--  sedlib reports structured diagnostics of its own. This package is the one
--  place that decides which sed diagnostic code each engine code corresponds
--  to, so compilation and execution cannot drift apart in how they classify
--  the same engine failure.
--
--  It depends on sedlib and on sed diagnostics and on nothing else. Callers
--  supply the source location, because only they know whether an offset in
--  the combined script maps to a -f file or to a -e expression.
package Sed.Engine is

   --  Map an engine diagnostic code to a sed diagnostic code.
   --
   --  @param Code Engine diagnostic code.
   --  @return Corresponding sed diagnostic code.
   function Code_Of
     (Code : Sedlib.Diagnostics.Diagnostic_Code)
      return Sed.Diagnostics.Diagnostic_Code;

   --  Whether an engine diagnostic should be reported to the user at all.
   --
   --  Only errors are reported. sedlib also emits advisory diagnostics, such
   --  as a note about a repeated substitution flag, that POSIX sed does not
   --  produce and that must not appear on standard error.
   --
   --  @param Item Engine diagnostic.
   --  @return True when the diagnostic is user-facing.
   function Is_Reportable (Item : Sedlib.Diagnostics.Diagnostic) return Boolean;

   --  Translate an engine diagnostic into a sed diagnostic.
   --
   --  The engine's stable code identifier is carried through as the technical
   --  detail parameter, and its related value, when present, as the offending
   --  value. Neither is an Ada package name, an exception name or a traceback.
   --
   --  @param Item Engine diagnostic.
   --  @param Location Source location the caller resolved for this diagnostic.
   --  @return Structured sed diagnostic.
   function Translate
     (Item : Sedlib.Diagnostics.Diagnostic;
      Location : Sed.Diagnostics.Source_Location :=
        Sed.Diagnostics.No_Location_Value) return Sed.Diagnostics.Diagnostic;

end Sed.Engine;

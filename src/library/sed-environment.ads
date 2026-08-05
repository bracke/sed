with Ada.Strings.Unbounded;

--  The process environment, captured as a value.
--
--  Everything the program needs to know about its surroundings -- requested
--  locale, colour preference, catalogue location and whether the standard
--  streams are terminals -- is gathered here once and then passed down as
--  data. No layer below this one reads an environment variable or asks the
--  operating system a question, so a test can present any environment it
--  likes without touching the host.
package Sed.Environment is

   package U renames Ada.Strings.Unbounded;

   type Process_Environment is record
      --  Requested locale name, for example "en" or "da". Empty means the
      --  catalogue default locale applies.
      Locale : U.Unbounded_String := U.Null_Unbounded_String;
      --  True when the NO_COLOR convention asks for unstyled output.
      No_Color : Boolean := False;
      --  Resolved message catalogue path; empty when none was found.
      Catalog_Path : U.Unbounded_String := U.Null_Unbounded_String;
      Standard_Output_Is_Terminal : Boolean := False;
      Standard_Error_Is_Terminal : Boolean := False;
      --  Development diagnostic mode, requested with SED_DEBUG.
      --
      --  It adds technical detail to the internal-error diagnostic. It never
      --  changes which messages are produced, what the exit status is, or
      --  what reaches standard output, and it is off unless asked for.
      Development_Diagnostics : Boolean := False;
   end record;

   --  Capture the real process environment.
   --
   --  This is a process adapter: together with the argument-list adapter it is
   --  the only production code that asks the host about itself.
   --
   --  @return Environment values for this process.
   function Capture return Process_Environment;

   --  Resolve the message catalogue relative to the running executable.
   --
   --  The search order is the SED_MESSAGE_CATALOG override, then
   --  <executable directory>/../share/sed/messages/catalog.txt. The second
   --  path is the same whether the program runs from an installation prefix
   --  or from the build tree, because bin/ and share/ are siblings in both.
   --
   --  @param Program_Path Path the process was started with.
   --  @return Catalogue path, or an empty string when none exists.
   function Resolve_Catalog_Path (Program_Path : String) return String;

end Sed.Environment;

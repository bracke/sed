with Sed.Localization;
with Sed.Terminal;

--  Rendering of structured diagnostics into localized text.
--
--  Rendering decides how a diagnostic looks, never what it means: severity,
--  recoverability and process-status effect come from the registry and are
--  read here, not chosen here.
--
--  Every untrusted value is escaped before it reaches a message argument, so
--  a crafted path, label or regular-expression fragment cannot inject escape
--  sequences into the terminal. Styling is applied to whole rendered parts
--  after escaping, which is why a styled and an unstyled diagnostic carry the
--  same plain text.
package Sed.Diagnostics.Rendering is

   --  Render one diagnostic as a single line, without a trailing newline.
   --
   --  @param Item Diagnostic to render.
   --  @param Catalog Message catalogue.
   --  @param Policy Styling policy for the destination.
   --  @return Localized diagnostic line.
   function Render
     (Item : Diagnostic;
      Catalog : Sed.Localization.Catalog;
      Policy : Sed.Terminal.Style_Policy) return String;

   --  Render the related location of a diagnostic as a note line.
   --
   --  @param Item Diagnostic whose related location to render.
   --  @param Catalog Message catalogue.
   --  @param Policy Styling policy for the destination.
   --  @return Localized note line, or an empty string when there is none.
   function Render_Related
     (Item : Diagnostic;
      Catalog : Sed.Localization.Catalog;
      Policy : Sed.Terminal.Style_Policy) return String;

   --  Render a source location on its own.
   --
   --  @param Location Location to render.
   --  @param Catalog Message catalogue.
   --  @return Localized location text, or an empty string.
   function Render_Location
     (Location : Source_Location;
      Catalog : Sed.Localization.Catalog) return String;

   --  Render the hint that points at --help.
   --
   --  @param Catalog Message catalogue.
   --  @param Policy Styling policy for the destination.
   --  @return Localized hint line.
   function Render_Hint
     (Catalog : Sed.Localization.Catalog;
      Policy : Sed.Terminal.Style_Policy) return String;

end Sed.Diagnostics.Rendering;

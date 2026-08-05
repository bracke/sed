private with Ada.Strings.Unbounded;
private with Messages.Arguments;
private with Messages.Runtime;

--  Adapter over the message catalogue.
--
--  This is the only package that names the message formatting library. Every
--  user-facing string in the program -- usage, help, option descriptions,
--  version labels, diagnostics, hints -- is resolved through here from a
--  stable key, so no layer builds a sentence by concatenating fragments and
--  no layer assumes English word order.
--
--  Sed data never passes through this package. Script text, option spellings,
--  labels, file names and source excerpts appear only as arguments, and are
--  escaped by the caller before they get here.
--
--  When no catalogue can be loaded the adapter renders each message as its
--  own key. That is a visible installation fault rather than a silent
--  substitution of hard-coded English, and it is covered by a test.
package Sed.Localization is

   type Catalog is limited private;

   --  Load a catalogue and select the active locale.
   --
   --  @param Item Catalogue to initialize.
   --  @param Catalog_Path Path to the catalogue file; may be empty.
   --  @param Locale Requested locale name; empty selects the catalogue
   --    default locale.
   procedure Initialize
     (Item : in out Catalog;
      Catalog_Path : String;
      Locale : String);

   --  @param Item Catalogue to inspect.
   --  @return True when messages resolve from a real catalogue.
   function Is_Valid (Item : Catalog) return Boolean;

   --  @param Item Catalogue to inspect.
   --  @return Active locale name, possibly empty.
   function Locale (Item : Catalog) return String;

   --  Named arguments for a message.
   type Parameters is limited private;

   --  @param Args Argument set to update.
   --  @param Name Argument name used in the template.
   --  @param Value Text value; the caller has already escaped it.
   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : String);

   --  @param Args Argument set to update.
   --  @param Name Argument name used in the template.
   --  @param Value Integer value, formatted by the catalogue.
   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : Line_Count);

   --  Render a message with no arguments.
   --
   --  @param Item Catalogue to render from.
   --  @param Key Stable message key.
   --  @return Rendered text, or the key when it cannot be rendered.
   function Text (Item : Catalog; Key : String) return String;

   --  Render a message with named arguments.
   --
   --  @param Item Catalogue to render from.
   --  @param Key Stable message key.
   --  @param Args Named arguments.
   --  @return Rendered text, or the key when it cannot be rendered.
   function Text
     (Item : Catalog;
      Key : String;
      Args : Parameters) return String;

   --  Whether a key resolves in the active locale or its fallback.
   --
   --  Used by catalogue validation rather than by rendering, which always
   --  degrades to the key instead of failing.
   --
   --  @param Item Catalogue to inspect.
   --  @param Key Stable message key.
   --  @return True when the key resolves.
   function Has_Key (Item : Catalog; Key : String) return Boolean;

private

   package U renames Ada.Strings.Unbounded;

   type Catalog is limited record
      Runtime : Messages.Runtime.Instance;
      Locale : U.Unbounded_String := U.Null_Unbounded_String;
      Valid : Boolean := False;
   end record;

   type Parameters is limited record
      Values : Messages.Arguments.Arguments;
   end record;

end Sed.Localization;

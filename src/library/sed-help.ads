with Sed.IO;
with Sed.Localization;
with Sed.Terminal;

--  Help and version output.
--
--  Both are administrative standard-output modes that run before any script
--  is loaded, any input operand is opened and any w destination is created.
--  Every line comes from the message catalogue, and the option lines are
--  driven by the same registry that drives parsing, so help cannot describe
--  an option the program does not accept.
package Sed.Help is

   --  Write the full help text.
   --
   --  @param Target Standard output stream.
   --  @param Catalog Message catalogue.
   --  @param Policy Styling policy for standard output.
   --  @param Success True when every line reached the stream.
   procedure Write_Help
     (Target : in out Sed.IO.Output_Stream_Interface'Class;
      Catalog : Sed.Localization.Catalog;
      Policy : Sed.Terminal.Style_Policy;
      Success : out Boolean);

   --  Write the version text.
   --
   --  @param Target Standard output stream.
   --  @param Catalog Message catalogue.
   --  @param Policy Styling policy for standard output.
   --  @param Success True when every line reached the stream.
   procedure Write_Version
     (Target : in out Sed.IO.Output_Stream_Interface'Class;
      Catalog : Sed.Localization.Catalog;
      Policy : Sed.Terminal.Style_Policy;
      Success : out Boolean);

end Sed.Help;

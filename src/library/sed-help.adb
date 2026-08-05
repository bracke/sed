with Sed.Command_Line.Options;
with Sed.Version;

package body Sed.Help is

   package L renames Sed.Localization;
   package T renames Sed.Terminal;
   package O renames Sed.Command_Line.Options;

   ----------------
   -- Write_Help --
   ----------------

   procedure Write_Help
     (Target : in out Sed.IO.Output_Stream_Interface'Class;
      Catalog : L.Catalog;
      Policy : T.Style_Policy;
      Success : out Boolean)
   is
      Failed : Boolean := False;

      --  Write one line, remembering the first failure.
      procedure Put (Text : String);

      --  Write a heading line.
      procedure Heading (Key : String);

      --  Write an ordinary line resolved from the catalogue.
      procedure Body_Text (Key : String);

      --  Write an empty separating line.
      procedure Blank;

      ---------
      -- Put --
      ---------

      procedure Put (Text : String) is
         Result : Sed.IO.IO_Result;
      begin
         if Failed then
            return;
         end if;

         Target.Write (Text & ASCII.LF, Result);

         if Sed.IO.Is_Failure (Result) then
            Failed := True;
         end if;
      end Put;

      -------------
      -- Heading --
      -------------

      procedure Heading (Key : String) is
      begin
         Put (T.Style (Policy, L.Text (Catalog, Key), T.Heading_Element));
      end Heading;

      ---------------
      -- Body_Text --
      ---------------

      procedure Body_Text (Key : String) is
      begin
         Put (L.Text (Catalog, Key));
      end Body_Text;

      -----------
      -- Blank --
      -----------

      procedure Blank is
      begin
         Put ("");
      end Blank;

   begin
      Heading ("sed.help.usage.heading");
      Body_Text ("sed.help.usage.positional");
      Body_Text ("sed.help.usage.expressions");
      Body_Text ("sed.help.usage.script_files");
      Blank;
      Body_Text ("sed.help.summary");
      Blank;

      Heading ("sed.help.options.heading");

      --  Option lines come from the option registry, so help and parsing can
      --  never describe different sets of options.
      for Id in O.Option_Id loop
         Body_Text (O.Help_Key (Id));
      end loop;

      Body_Text ("sed.option.terminator");
      Blank;

      Heading ("sed.help.operands.heading");
      Body_Text ("sed.help.operands.script");
      Body_Text ("sed.help.operands.files");
      Body_Text ("sed.help.operands.stdin");
      Blank;

      Heading ("sed.help.exit.heading");
      Body_Text ("sed.help.exit.success");
      Body_Text ("sed.help.exit.processing");
      Body_Text ("sed.help.exit.invocation");
      Body_Text ("sed.help.exit.internal");
      Blank;

      Heading ("sed.help.conformance.heading");
      Body_Text ("sed.help.conformance.summary");

      Success := not Failed;
   end Write_Help;

   -------------------
   -- Write_Version --
   -------------------

   procedure Write_Version
     (Target : in out Sed.IO.Output_Stream_Interface'Class;
      Catalog : L.Catalog;
      Policy : T.Style_Policy;
      Success : out Boolean)
   is
      Failed : Boolean := False;

      --  Write one line, remembering the first failure.
      procedure Put (Text : String);

      ---------
      -- Put --
      ---------

      procedure Put (Text : String) is
         Result : Sed.IO.IO_Result;
      begin
         if Failed then
            return;
         end if;

         Target.Write (Text & ASCII.LF, Result);

         if Sed.IO.Is_Failure (Result) then
            Failed := True;
         end if;
      end Put;

   begin
      declare
         Args : L.Parameters;
      begin
         L.Set
           (Args,
            "program",
            T.Style (Policy, Program_Name, T.Program_Name_Element));
         L.Set (Args, "version", Sed.Version.Value);
         Put (L.Text (Catalog, "sed.version.program", Args));
      end;

      declare
         Args : L.Parameters;
      begin
         L.Set (Args, "name", Sed.Version.Engine_Name);
         L.Set (Args, "version", Sed.Version.Engine_Version);
         Put (L.Text (Catalog, "sed.version.engine", Args));
      end;

      declare
         Args : L.Parameters;
      begin
         L.Set (Args, "license", Sed.Version.License);
         Put (L.Text (Catalog, "sed.version.license", Args));
      end;

      Success := not Failed;
   end Write_Version;

end Sed.Help;

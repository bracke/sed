with Sed.Diagnostics.Quoting;
with Sed.Diagnostics.Registry;

package body Sed.Diagnostics.Rendering is

   package L renames Sed.Localization;
   package T renames Sed.Terminal;

   --  Catalogue argument name for each diagnostic parameter.
   function Argument_Name (Name : Parameter_Name) return String
     is (case Name is
           when Path        => "path",
           when Option      => "option",
           when Value       => "value",
           when Detail      => "detail",
           when Capability  => "capability",
           when Requirement => "requirement",
           when Limit       => "limit",
           when Actual      => "actual",
           when Allowed     => "allowed");

   --  Values that name a thing the user typed are quoted so that empty or
   --  space-padded values stay visible; values that are already delimited by
   --  the message frame are only escaped.
   function Is_Quoted (Name : Text_Parameter) return Boolean
     is (Name in Option | Value);

   --  Terminal element used for a severity.
   function Severity_Element (Level : Severity) return T.Element
     is (case Level is
           when Error       => T.Error_Element,
           when Warning     => T.Warning_Element,
           when Information => T.Information_Element);

   --  Catalogue key of a severity label.
   function Severity_Key (Level : Severity) return String
     is (case Level is
           when Error       => "sed.diagnostic.severity.error",
           when Warning     => "sed.diagnostic.severity.warning",
           when Information => "sed.diagnostic.severity.information");

   --  Fill Args with every parameter the diagnostic supplies, escaped.
   procedure Add_Parameters (Item : Diagnostic; Args : in out L.Parameters);

   --  Render the message body of a diagnostic, including its detail.
   function Render_Message
     (Item : Diagnostic;
      Catalog : L.Catalog) return String;

   --  Assemble a frame line from its parts.
   function Frame
     (Catalog : L.Catalog;
      Policy : T.Style_Policy;
      Location : String;
      Level : Severity;
      Message : String;
      Key : String) return String;

   --------------------
   -- Add_Parameters --
   --------------------

   procedure Add_Parameters (Item : Diagnostic; Args : in out L.Parameters) is
      Supplied : constant Parameter_Set := Present (Item);
   begin
      for Name in Text_Parameter loop
         if Supplied (Name) then
            declare
               Raw : constant String := Text_Of (Item, Name);
            begin
               L.Set
                 (Args,
                  Argument_Name (Name),
                  (if Is_Quoted (Name)
                   then Quoting.Quoted (Raw)
                   else Quoting.Escape (Raw)));
            end;
         end if;
      end loop;

      for Name in Integer_Parameter loop
         if Supplied (Name) then
            L.Set (Args, Argument_Name (Name), Number_Of (Item, Name));
         end if;
      end loop;
   end Add_Parameters;

   ---------------------
   -- Render_Location --
   ---------------------

   function Render_Location
     (Location : Source_Location;
      Catalog : L.Catalog) return String
   is
      Args : L.Parameters;
   begin
      case Location.Kind is
         when No_Location =>
            return "";

         when Path_Location =>
            L.Set (Args, "path", Quoting.Escape (U.To_String (Location.Path)));

            if Location.Line = 0 then
               return L.Text (Catalog, "sed.location.path", Args);
            end if;

            L.Set (Args, "line", Location.Line);

            if Location.Column = 0 then
               return L.Text (Catalog, "sed.location.path_line", Args);
            end if;

            L.Set (Args, "column", Location.Column);
            return L.Text (Catalog, "sed.location.path_line_column", Args);

         when Expression_Location =>
            L.Set (Args, "index", Line_Count (Location.Occurrence));

            if Location.Line = 0 then
               return L.Text (Catalog, "sed.location.expression", Args);
            end if;

            L.Set (Args, "line", Location.Line);

            if Location.Column = 0 then
               return L.Text (Catalog, "sed.location.expression_line", Args);
            end if;

            L.Set (Args, "column", Location.Column);
            return L.Text
              (Catalog, "sed.location.expression_line_column", Args);
      end case;
   end Render_Location;

   --------------------
   -- Render_Message --
   --------------------

   function Render_Message
     (Item : Diagnostic;
      Catalog : L.Catalog) return String
   is
      Args : L.Parameters;
      Key : constant String := Registry.Message_Key (Code (Item));
   begin
      Add_Parameters (Item, Args);

      declare
         Body_Text : constant String := L.Text (Catalog, Key, Args);
      begin
         if not Present (Item) (Detail) then
            return Body_Text;
         end if;

         --  The technical detail is appended through its own template so that
         --  a translation controls the punctuation and the order.
         declare
            Detail_Args : L.Parameters;
         begin
            L.Set (Detail_Args, "message", Body_Text);
            L.Set
              (Detail_Args,
               "detail",
               Quoting.Escape (Text_Of (Item, Detail)));
            return L.Text (Catalog, "sed.diagnostic.detail", Detail_Args);
         end;
      end;
   end Render_Message;

   -----------
   -- Frame --
   -----------

   function Frame
     (Catalog : L.Catalog;
      Policy : T.Style_Policy;
      Location : String;
      Level : Severity;
      Message : String;
      Key : String) return String
   is
      Args : L.Parameters;
   begin
      L.Set
        (Args,
         "program",
         T.Style (Policy, Program_Name, T.Program_Name_Element));

      L.Set
        (Args,
         "severity",
         T.Style
           (Policy,
            L.Text (Catalog, Severity_Key (Level)),
            Severity_Element (Level)));

      L.Set (Args, "message", Message);

      if Location'Length > 0 then
         L.Set
           (Args, "location", T.Style (Policy, Location, T.Location_Element));
      end if;

      return L.Text (Catalog, Key, Args);
   end Frame;

   ------------
   -- Render --
   ------------

   function Render
     (Item : Diagnostic;
      Catalog : L.Catalog;
      Policy : T.Style_Policy) return String
   is
      Location : constant String :=
        Render_Location (Location_Of (Item), Catalog);
   begin
      return Frame
        (Catalog => Catalog,
         Policy => Policy,
         Location => Location,
         Level => Severity_Of (Item),
         Message => Render_Message (Item, Catalog),
         Key =>
           (if Location'Length > 0
            then "sed.diagnostic.with_location"
            else "sed.diagnostic.without_location"));
   end Render;

   --------------------
   -- Render_Related --
   --------------------

   function Render_Related
     (Item : Diagnostic;
      Catalog : L.Catalog;
      Policy : T.Style_Policy) return String
   is
      Location : constant String :=
        Render_Location (Related_Of (Item), Catalog);
   begin
      if Location'Length = 0 then
         return "";
      end if;

      return Frame
        (Catalog => Catalog,
         Policy => Policy,
         Location => Location,
         Level => Information,
         Message => Render_Message (Item, Catalog),
         Key => "sed.diagnostic.note");
   end Render_Related;

   -----------------
   -- Render_Hint --
   -----------------

   function Render_Hint
     (Catalog : L.Catalog;
      Policy : T.Style_Policy) return String
   is
      Args : L.Parameters;
   begin
      L.Set
        (Args,
         "program",
         T.Style (Policy, Program_Name, T.Program_Name_Element));
      L.Set
        (Args,
         "option",
         T.Style (Policy, Quoting.Quoted ("--help"), T.Option_Element));

      return L.Text (Catalog, "sed.hint.try_help", Args);
   end Render_Hint;

end Sed.Diagnostics.Rendering;

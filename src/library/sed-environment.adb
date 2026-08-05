with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Sed.IO.Process_Streams;

package body Sed.Environment is

   Catalog_Override : constant String := "SED_MESSAGE_CATALOG";

   --  Relative location of the catalogue with respect to the executable's
   --  directory. Identical for an installation prefix and for the build tree.
   Catalog_Suffix : constant String := "share/sed/messages/catalog.txt";

   --  Value of the first environment variable that is set and non-empty.
   function First_Set (Names : String) return String;

   --  Locale name from the usual POSIX environment variables, reduced to the
   --  language and region part: "da_DK.UTF-8" becomes "da-DK".
   function Requested_Locale return String;

   ---------------
   -- First_Set --
   ---------------

   function First_Set (Names : String) return String is
      First : Positive := Names'First;
   begin
      for Index in Names'Range loop
         if Names (Index) = ' ' or else Index = Names'Last then
            declare
               Last : constant Natural :=
                 (if Names (Index) = ' ' then Index - 1 else Index);
               Name : constant String := Names (First .. Last);
            begin
               if Name'Length > 0
                 and then Ada.Environment_Variables.Exists (Name)
                 and then Ada.Environment_Variables.Value (Name) /= ""
               then
                  return Ada.Environment_Variables.Value (Name);
               end if;

               First := Index + 1;
            end;
         end if;
      end loop;

      return "";
   end First_Set;

   -----------------------
   -- Requested_Locale --
   -----------------------

   function Requested_Locale return String is
      Raw : constant String := First_Set ("LC_ALL LC_MESSAGES LANG");
      Last : Natural := Raw'Last;
   begin
      if Raw'Length = 0 then
         return "";
      end if;

      --  Drop the codeset and modifier parts, which the catalogue does not
      --  distinguish.
      for Index in Raw'Range loop
         if Raw (Index) = '.' or else Raw (Index) = '@' then
            Last := Index - 1;
            exit;
         end if;
      end loop;

      declare
         Trimmed : constant String := Raw (Raw'First .. Last);
         Result : String := Trimmed;
      begin
         if Trimmed = "C" or else Trimmed = "POSIX" then
            --  The POSIX locale asks for the catalogue default rather than a
            --  translation.
            return "";
         end if;

         for Index in Result'Range loop
            if Result (Index) = '_' then
               Result (Index) := '-';
            end if;
         end loop;

         return Result;
      end;
   end Requested_Locale;

   --------------------------
   -- Resolve_Catalog_Path --
   --------------------------

   function Resolve_Catalog_Path (Program_Path : String) return String is

      --  Whether Path names an existing ordinary file.
      function Is_File (Path : String) return Boolean;

      -------------
      -- Is_File --
      -------------

      function Is_File (Path : String) return Boolean is
         use type Ada.Directories.File_Kind;
      begin
         return Path'Length > 0
           and then Ada.Directories.Exists (Path)
           and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
      exception
         when others =>
            return False;
      end Is_File;

      Override : constant String := First_Set (Catalog_Override);

   begin
      if Override'Length > 0 and then Is_File (Override) then
         return Override;
      end if;

      if Program_Path'Length = 0 then
         return "";
      end if;

      declare
         Directory : constant String :=
           Ada.Directories.Containing_Directory
             (Ada.Directories.Full_Name (Program_Path));
         Prefix : constant String :=
           Ada.Directories.Containing_Directory (Directory);
         --  Built by concatenation rather than through Ada.Directories.Compose,
         --  which accepts only a simple name and rejects a relative path.
         Candidate : constant String := Prefix & '/' & Catalog_Suffix;
      begin
         if Is_File (Candidate) then
            return Candidate;
         end if;
      end;

      return "";

   exception
      when others =>
         --  A host that cannot resolve the executable path leaves the program
         --  without a catalogue; that is reported through rendering rather
         --  than by failing here.
         return "";
   end Resolve_Catalog_Path;

   -------------
   -- Capture --
   -------------

   function Capture return Process_Environment is
      Result : Process_Environment;
   begin
      Result.Locale := U.To_Unbounded_String (Requested_Locale);
      Result.No_Color :=
        Ada.Environment_Variables.Exists ("NO_COLOR")
        and then Ada.Environment_Variables.Value ("NO_COLOR") /= "";
      Result.Catalog_Path :=
        U.To_Unbounded_String
          (Resolve_Catalog_Path (Ada.Command_Line.Command_Name));
      Result.Development_Diagnostics :=
        Ada.Environment_Variables.Exists ("SED_DEBUG")
        and then Ada.Environment_Variables.Value ("SED_DEBUG") /= "";
      Result.Standard_Output_Is_Terminal :=
        Sed.IO.Process_Streams.Descriptor_Is_Terminal (1);
      Result.Standard_Error_Is_Terminal :=
        Sed.IO.Process_Streams.Descriptor_Is_Terminal (2);
      return Result;
   end Capture;

end Sed.Environment;

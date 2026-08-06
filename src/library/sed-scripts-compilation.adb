with Sedlib.Compilation;
with Sedlib.Diagnostics;
with Sedlib.Options;
with Sedlib.Text;
with Sed.Engine;

package body Sed.Scripts.Compilation is

   package D renames Sed.Diagnostics;

   --  Compile options that select the POSIX language.
   --
   --  Portable mode refuses GNU extensions, byte mode keeps arbitrary octets
   --  intact, and resource commands stay enabled because POSIX defines r and
   --  w. Invalid UTF-8 is treated as bytes rather than rejected: POSIX sed
   --  operates on octets, and refusing a byte sequence would make sed unable
   --  to edit files it is expected to pass through unchanged.
   function Portable_Options return Sedlib.Options.Compile_Options;

   --  Collect the distinct write destinations a compiled program names.
   procedure Collect_Destinations
     (Program : Sedlib.Programs.Program;
      Into : out Name_Vectors.Vector);

   -----------------------
   -- Portable_Options --
   -----------------------

   function Portable_Options return Sedlib.Options.Compile_Options is
      Options : Sedlib.Options.Compile_Options :=
        Sedlib.Options.Default_Compile_Options;

      --  The engine's default compile bounds suit an embedded library, where
      --  a caller wants a hostile script rejected early. A command-line sed
      --  must accept whatever script the user actually wrote, so the bounds
      --  are raised to values no realistic script reaches. Exceeding one is
      --  still a structured diagnostic rather than a crash or a truncation.
      Byte_Bound : constant Natural := 2 ** 30;

      Limits : constant Sedlib.Options.Compile_Limits :=
        (Script_Bytes => Byte_Bound,
         Command_Count => Natural'Last,
         Group_Depth => Natural'Last,
         Label_Count => Natural'Last,
         Label_Length => Byte_Bound,
         Expression_Bytes => Byte_Bound,
         --  The regexp engine keeps a fixed state array, so this only lifts
         --  sed's own bound out of the way; what a long expression finally
         --  runs into is the engine's ceiling, reported as a diagnostic.
         Expression_States => Natural'Last,
         Replacement_Bytes => Byte_Bound,
         Text_Operand_Bytes => Byte_Bound,
         Diagnostic_Count => Positive'Last);
   begin
      Sedlib.Options.Set_Mode (Options, Sedlib.Options.Portable_Mode);
      Sedlib.Options.Set_Text_Mode (Options, Sedlib.Options.Byte_Mode);
      Sedlib.Options.Set_UTF8_Policy
        (Options, Sedlib.Options.Treat_Invalid_As_Bytes);
      Sedlib.Options.Set_Resource_Policy
        (Options, Sedlib.Options.Allow_Resource_Commands);

      --  POSIX sed is defined in terms of basic regular expressions: \( \)
      --  group, \{ \} bound, and ( ) { } + ? | are ordinary characters.
      Sedlib.Options.Set_Regexp_Dialect
        (Options, Sedlib.Options.Basic_Dialect);

      Sedlib.Options.Set_Limits (Options, Limits);
      return Options;
   end Portable_Options;

   --------------------------
   -- Collect_Destinations --
   --------------------------

   procedure Collect_Destinations
     (Program : Sedlib.Programs.Program;
      Into : out Name_Vectors.Vector)
   is
      use type Sedlib.Programs.Operation_Kind;

      --  Append a name unless an identical one is already present, so that a
      --  destination referenced by several commands is created exactly once.
      procedure Include (Name : String);

      -------------
      -- Include --
      -------------

      procedure Include (Name : String) is
      begin
         if Name'Length = 0 then
            return;
         end if;

         for Existing of Into loop
            if Existing = Name then
               return;
            end if;
         end loop;

         Into.Append (Name);
      end Include;

   begin
      Into := Name_Vectors.Empty_Vector;

      for Index in 1 .. Sedlib.Programs.Instruction_Count (Program) loop
         declare
            Kind : constant Sedlib.Programs.Operation_Kind :=
              Sedlib.Programs.Kind (Program, Index);
         begin
            if Kind = Sedlib.Programs.Resource_Write
              or else Kind = Sedlib.Programs.Resource_Write_First_Line
            then
               Include
                 (Sedlib.Text.To_String
                    (Sedlib.Programs.Text_Operand (Program, Index)));

            elsif Kind = Sedlib.Programs.Substitute
              and then Sedlib.Programs.Substitution_Has_Write (Program, Index)
            then
               Include
                 (Sedlib.Text.To_String
                    (Sedlib.Programs.Substitution_Write_Name (Program, Index)));
            end if;
         end;
      end loop;
   end Collect_Destinations;

   -------------
   -- Compile --
   -------------

   procedure Compile
     (Set : Source_Set;
      Program : out Compiled_Program;
      Diagnostics : out D.Diagnostic_List;
      Success : out Boolean)
   is
      Script : constant String := Combined_Text (Set);

      Result : constant Sedlib.Compilation.Compilation_Result :=
        Sedlib.Compilation.Compile (Script, Portable_Options);

      Reported : constant Sedlib.Diagnostics.Diagnostic_List :=
        Sedlib.Compilation.Diagnostics (Result);
   begin
      Program := (Valid => False,
                  Program => Sedlib.Programs.Invalid_Program,
                  Destinations => Name_Vectors.Empty_Vector);
      Diagnostics := D.Empty_List;

      for Index in 1 .. Sedlib.Diagnostics.Length (Reported) loop
         declare
            Item : constant Sedlib.Diagnostics.Diagnostic :=
              Sedlib.Diagnostics.Element (Reported, Index);
         begin
            if Sed.Engine.Is_Reportable (Item) then
               --  The engine reports a byte offset into the combined script;
               --  the source set turns that back into the unit, line and
               --  column the user actually wrote.
               D.Append_Unique
                 (Diagnostics,
                  Sed.Engine.Translate
                    (Item, Locate (Set, Item.Span.First.Offset)));
            end if;
         end;
      end loop;

      Success := Sedlib.Compilation.Succeeded (Result);

      if Success then
         Program.Program := Sedlib.Compilation.Compiled_Program (Result);
         Program.Valid := True;
         Collect_Destinations (Program.Program, Program.Destinations);
      end if;
   end Compile;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (Item : Compiled_Program) return Boolean is
   begin
      return Item.Valid;
   end Is_Valid;

   -----------------------------
   -- Write_Destination_Count --
   -----------------------------

   function Write_Destination_Count (Item : Compiled_Program) return Natural is
   begin
      return Natural (Item.Destinations.Length);
   end Write_Destination_Count;

   -----------------------
   -- Write_Destination --
   -----------------------

   function Write_Destination
     (Item : Compiled_Program; Index : Positive) return String is
   begin
      return Item.Destinations (Index);
   end Write_Destination;

end Sed.Scripts.Compilation;

package body Sed.Command_Line.Options is

   package D renames Sed.Diagnostics;

   --  The authoritative option table. The aggregate must cover Option_Id, so
   --  adding an option without describing it here is a compile-time error.
   Table : constant array (Option_Id) of Option_Descriptor :=
     [Quiet_Option =>
        (Spelling           => Spellings.To_Bounded_String ("-n"),
         Form               => Short_Option,
         Requirement        => No_Argument,
         Attachment_Allowed => False,
         Conformance        => POSIX_Option,
         Help_Key           => Keys.To_Bounded_String ("sed.option.quiet"),
         Selects_Mode       => Run_Mode),

      Expression_Option =>
        (Spelling           => Spellings.To_Bounded_String ("-e"),
         Form               => Short_Option,
         Requirement        => Required_Argument,
         Attachment_Allowed => True,
         Conformance        => POSIX_Option,
         Help_Key           => Keys.To_Bounded_String ("sed.option.expression"),
         Selects_Mode       => Run_Mode),

      Script_File_Option =>
        (Spelling           => Spellings.To_Bounded_String ("-f"),
         Form               => Short_Option,
         Requirement        => Required_Argument,
         Attachment_Allowed => True,
         Conformance        => POSIX_Option,
         Help_Key           => Keys.To_Bounded_String ("sed.option.script_file"),
         Selects_Mode       => Run_Mode),

      Help_Option =>
        (Spelling           => Spellings.To_Bounded_String ("--help"),
         Form               => Long_Option,
         Requirement        => No_Argument,
         Attachment_Allowed => False,
         Conformance        => Implementation_Option,
         Help_Key           => Keys.To_Bounded_String ("sed.option.help"),
         Selects_Mode       => Help_Mode),

      Version_Option =>
        (Spelling           => Spellings.To_Bounded_String ("--version"),
         Form               => Long_Option,
         Requirement        => No_Argument,
         Attachment_Allowed => False,
         Conformance        => Implementation_Option,
         Help_Key           => Keys.To_Bounded_String ("sed.option.version"),
         Selects_Mode       => Version_Mode),

      Color_Option =>
        (Spelling           => Spellings.To_Bounded_String ("--color"),
         Form               => Long_Option,
         Requirement        => Required_Argument,
         --  Long options take their argument only in attached form, so
         --  "--color" alone is a missing-argument failure rather than
         --  swallowing the next operand.
         Attachment_Allowed => True,
         Conformance        => Implementation_Option,
         Help_Key           => Keys.To_Bounded_String ("sed.option.color"),
         Selects_Mode       => Run_Mode)];

   ----------------
   -- Descriptor --
   ----------------

   function Descriptor (Id : Option_Id) return Option_Descriptor is
   begin
      return Table (Id);
   end Descriptor;

   --------------
   -- Spelling --
   --------------

   function Spelling (Id : Option_Id) return String is
   begin
      return Spellings.To_String (Table (Id).Spelling);
   end Spelling;

   --------------
   -- Help_Key --
   --------------

   function Help_Key (Id : Option_Id) return String is
   begin
      return Keys.To_String (Table (Id).Help_Key);
   end Help_Key;

   -----------
   -- Parse --
   -----------

   function Parse (List : Arguments.Argument_List'Class) return Token_Parse is

      Result : Token_Parse;

      --  Ordinal of the next script declaration in overall command-line order.
      Next_Ordinal : Positive := 1;
      Inline_Count : Natural := 0;
      File_Count : Natural := 0;

      --  Set when "--" has been seen; every later argument is an operand.
      After_Terminator : Boolean := False;

      Index : Positive := 1;

      --  Record a structured failure and stop parsing.
      procedure Reject (Item : D.Diagnostic);

      --  Look up a short option by its letter.
      function Short_Option_Of (Letter : Character; Id : out Option_Id) return Boolean;

      --  Look up a long option by its full spelling.
      function Long_Option_Of (Name : String; Id : out Option_Id) return Boolean;

      --  Record a script declaration produced by -e or -f.
      procedure Add_Script
        (Kind : Script_Source_Kind;
         Text : String;
         At_Argument : Positive);

      --  Apply an option that takes an argument.
      procedure Apply_With_Argument
        (Id : Option_Id;
         Text : String;
         At_Argument : Positive;
         As_Written : String)
        with Pre => Table (Id).Requirement = Required_Argument;

      ------------
      -- Reject --
      ------------

      procedure Reject (Item : D.Diagnostic) is
      begin
         Result.Ok := False;
         Result.Diagnostic := Item;
      end Reject;

      ---------------------
      -- Short_Option_Of --
      ---------------------

      function Short_Option_Of (Letter : Character; Id : out Option_Id) return Boolean is
         Wanted : constant String := ['-', Letter];
      begin
         for Candidate in Option_Id loop
            if Table (Candidate).Form = Short_Option
              and then Spellings.To_String (Table (Candidate).Spelling) = Wanted
            then
               Id := Candidate;
               return True;
            end if;
         end loop;

         Id := Option_Id'First;
         return False;
      end Short_Option_Of;

      --------------------
      -- Long_Option_Of --
      --------------------

      function Long_Option_Of (Name : String; Id : out Option_Id) return Boolean is
      begin
         for Candidate in Option_Id loop
            if Table (Candidate).Form = Long_Option
              and then Spellings.To_String (Table (Candidate).Spelling) = Name
            then
               Id := Candidate;
               return True;
            end if;
         end loop;

         Id := Option_Id'First;
         return False;
      end Long_Option_Of;

      ----------------
      -- Add_Script --
      ----------------

      procedure Add_Script
        (Kind : Script_Source_Kind;
         Text : String;
         At_Argument : Positive)
      is
         Occurrence : Positive;
      begin
         case Kind is
            when Inline_Expression =>
               Inline_Count := Inline_Count + 1;
               Occurrence := Inline_Count;

            when Script_File =>
               File_Count := File_Count + 1;
               Occurrence := File_Count;
         end case;

         Result.Scripts.Append
           (Script_Declaration'
              (Kind           => Kind,
               Value          => U.To_Unbounded_String (Text),
               Argument_Index => At_Argument,
               Occurrence     => Occurrence,
               Ordinal        => Next_Ordinal,
               Positional     => False));

         Next_Ordinal := Next_Ordinal + 1;
         Result.Script_Option_Seen := True;
      end Add_Script;

      -------------------------
      -- Apply_With_Argument --
      -------------------------

      procedure Apply_With_Argument
        (Id : Option_Id;
         Text : String;
         At_Argument : Positive;
         As_Written : String) is
      begin
         case Id is
            when Expression_Option =>
               Add_Script (Inline_Expression, Text, At_Argument);

            when Script_File_Option =>
               Add_Script (Script_File, Text, At_Argument);

            when Color_Option =>
               if Text = "auto" then
                  Result.Color := Color_Auto;
               elsif Text = "always" then
                  Result.Color := Color_Always;
               elsif Text = "never" then
                  Result.Color := Color_Never;
               else
                  declare
                     Item : D.Diagnostic := D.Make (D.Invalid_Option_Argument);
                  begin
                     D.Set (Item, D.Option, As_Written);
                     D.Set (Item, D.Value, Text);
                     Reject (Item);
                     return;
                  end;
               end if;

               Result.Color_Explicit := True;

            when Quiet_Option | Help_Option | Version_Option =>
               --  Excluded by the precondition: these options take no
               --  argument, so no caller can reach this alternative.
               null;
         end case;
      end Apply_With_Argument;

   begin
      Result.Ok := True;

      while Index <= List.Count loop
         declare
            Argument : constant String := List.Argument (Index);
         begin
            if After_Terminator
              or else Argument'Length = 0
              or else Argument (Argument'First) /= '-'
              or else Argument = "-"
            then
               --  A bare "-" names standard input and is never an option.
               Result.Operands.Append
                 (Raw_Operand'
                    (Text           => U.To_Unbounded_String (Argument),
                     Argument_Index => Index));

            elsif Argument = "--" then
               After_Terminator := True;

            elsif Argument'Length >= 2
              and then Argument (Argument'First .. Argument'First + 1) = "--"
            then
               --  Long option, possibly with an attached =value.
               declare
                  Body_Text : constant String :=
                    Argument (Argument'First .. Argument'Last);
                  Equals : Natural := 0;
                  Id : Option_Id;
               begin
                  for Position in Body_Text'Range loop
                     if Body_Text (Position) = '=' then
                        Equals := Position;
                        exit;
                     end if;
                  end loop;

                  declare
                     Name : constant String :=
                       (if Equals = 0 then Body_Text
                        else Body_Text (Body_Text'First .. Equals - 1));
                     Has_Value : constant Boolean := Equals /= 0;
                     Text : constant String :=
                       (if Has_Value then Body_Text (Equals + 1 .. Body_Text'Last)
                        else "");
                  begin
                     if not Long_Option_Of (Name, Id) then
                        declare
                           Item : D.Diagnostic := D.Make (D.Unknown_Option);
                        begin
                           D.Set (Item, D.Option, Name);
                           Reject (Item);
                           return Result;
                        end;
                     end if;

                     case Table (Id).Requirement is
                        when No_Argument =>
                           if Has_Value and then not Table (Id).Attachment_Allowed then
                              declare
                                 Item : D.Diagnostic :=
                                   D.Make (D.Invalid_Option_Argument);
                              begin
                                 D.Set (Item, D.Option, Name);
                                 D.Set (Item, D.Value, Text);
                                 Reject (Item);
                                 return Result;
                              end;
                           end if;

                           if Table (Id).Selects_Mode /= Run_Mode then
                              --  Administrative modes stop option processing
                              --  immediately, so nothing later is loaded.
                              Result.Mode := Table (Id).Selects_Mode;
                              return Result;
                           end if;

                        when Required_Argument =>
                           if not Has_Value then
                              declare
                                 Item : D.Diagnostic :=
                                   D.Make (D.Missing_Option_Argument);
                              begin
                                 D.Set (Item, D.Option, Name);
                                 Reject (Item);
                                 return Result;
                              end;
                           end if;

                           Apply_With_Argument (Id, Text, Index, Name);

                           if not Result.Ok then
                              return Result;
                           end if;
                     end case;
                  end;
               end;

            else
               --  Short option cluster: every letter is an option, and the
               --  first one that takes an argument consumes the rest of the
               --  word, or the following word.
               declare
                  Position : Positive := Argument'First + 1;
                  Id : Option_Id;
               begin
                  Cluster :
                  while Position <= Argument'Last loop
                     declare
                        Letter : constant Character := Argument (Position);
                        As_Written : constant String := ['-', Letter];
                     begin
                        if not Short_Option_Of (Letter, Id) then
                           declare
                              Item : D.Diagnostic := D.Make (D.Unknown_Option);
                           begin
                              D.Set (Item, D.Option, As_Written);
                              Reject (Item);
                              return Result;
                           end;
                        end if;

                        case Table (Id).Requirement is
                           when No_Argument =>
                              if Table (Id).Selects_Mode /= Run_Mode then
                                 Result.Mode := Table (Id).Selects_Mode;
                                 return Result;
                              end if;

                              if Id = Quiet_Option then
                                 --  Repeated -n is harmless.
                                 Result.Suppress := True;
                              end if;

                              Position := Position + 1;

                           when Required_Argument =>
                              if Position < Argument'Last then
                                 Apply_With_Argument
                                   (Id,
                                    Argument (Position + 1 .. Argument'Last),
                                    Index,
                                    As_Written);
                              elsif Index < List.Count then
                                 Index := Index + 1;
                                 Apply_With_Argument
                                   (Id, List.Argument (Index), Index, As_Written);
                              else
                                 declare
                                    Item : D.Diagnostic :=
                                      D.Make (D.Missing_Option_Argument);
                                 begin
                                    D.Set (Item, D.Option, As_Written);
                                    Reject (Item);
                                    return Result;
                                 end;
                              end if;

                              if not Result.Ok then
                                 return Result;
                              end if;

                              exit Cluster;
                        end case;
                     end;
                  end loop Cluster;
               end;
            end if;
         end;

         Index := Index + 1;
      end loop;

      return Result;
   end Parse;

end Sed.Command_Line.Options;

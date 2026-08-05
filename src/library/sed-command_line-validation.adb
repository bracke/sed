package body Sed.Command_Line.Validation is

   package D renames Sed.Diagnostics;

   --------------
   -- Validate --
   --------------

   function Validate (Item : Token_Parse) return Parse_Result is
      Result : Parse_Result;

      --  Index of the first operand that is an input operand rather than the
      --  positional script.
      First_Input : Positive := 1;

      --  Append one input operand, classifying "-" as standard input.
      procedure Add_Operand (Raw : Raw_Operand);

      -----------------
      -- Add_Operand --
      -----------------

      procedure Add_Operand (Raw : Raw_Operand) is
         Text : constant String := U.To_String (Raw.Text);
      begin
         Result.Item.Operands.Append
           (Input_Operand'
              (Kind           => (if Text = "-" then Standard_Input else Named_File),
               Name           => Raw.Text,
               Argument_Index => Raw.Argument_Index));
      end Add_Operand;

   begin
      if not Item.Ok then
         return
           (Ok         => False,
            Item       => <>,
            Diagnostic => Item.Diagnostic);
      end if;

      Result.Item.Mode := Item.Mode;
      Result.Item.Suppress := Item.Suppress;
      Result.Item.Color := Item.Color;
      Result.Item.Color_Explicit := Item.Color_Explicit;

      if Item.Mode /= Run_Mode then
         --  Help and version never load scripts or touch input operands.
         Result.Ok := True;
         return Result;
      end if;

      Result.Item.Scripts := Item.Scripts;

      if not Item.Script_Option_Seen then
         if Item.Operands.Is_Empty then
            return
              (Ok         => False,
               Item       => <>,
               Diagnostic => D.Make (D.Missing_Script));
         end if;

         --  The first operand is the script. It keeps full provenance so that
         --  diagnostics can point into it exactly as they would into -e text.
         declare
            Raw : constant Raw_Operand := Item.Operands.First_Element;
         begin
            Result.Item.Scripts.Append
              (Script_Declaration'
                 (Kind           => Inline_Expression,
                  Value          => Raw.Text,
                  Argument_Index => Raw.Argument_Index,
                  Occurrence     => 1,
                  Ordinal        => 1,
                  Positional     => True));
         end;

         First_Input := 2;
      end if;

      for Index in First_Input .. Natural (Item.Operands.Length) loop
         Add_Operand (Item.Operands (Index));
      end loop;

      Result.Ok := True;
      return Result;
   end Validate;

end Sed.Command_Line.Validation;

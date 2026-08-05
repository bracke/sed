private with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Sed.Diagnostics;

--  Command-line model: the vocabulary shared by option parsing and validation.
--
--  This layer is deliberately inert. It opens no files, initializes no engine,
--  renders no text and terminates nothing; it turns an argument list into a
--  structured invocation or a structured failure. It therefore depends on
--  Sed.Diagnostics for failure values and on nothing else in the project, and
--  in particular not on sedlib, the filesystem, messages or terminal styling.
package Sed.Command_Line is

   package U renames Ada.Strings.Unbounded;

   --  Where a unit of sed script text came from.
   type Script_Source_Kind is
     (
      --  Text supplied inline with -e, or as the positional script operand.
      Inline_Expression,
      --  A file named by -f.
      Script_File);

   --  One -e, -f or positional script occurrence.
   --
   --  Every occurrence is a distinct unit: two -e options are never merged,
   --  and the command-line order of all occurrences is preserved exactly.
   type Script_Declaration is record
      Kind : Script_Source_Kind := Inline_Expression;
      --  Inline script text, or the script file path, exactly as supplied.
      Value : U.Unbounded_String := U.Null_Unbounded_String;
      --  Index of the originating argument in the argument list.
      Argument_Index : Positive := 1;
      --  1-based index among declarations of the same kind, used for the
      --  localized "command line expression N" label.
      Occurrence : Positive := 1;
      --  1-based index in overall command-line order.
      Ordinal : Positive := 1;
      --  True when the script came from the positional operand rather than
      --  from an option.
      Positional : Boolean := False;
   end record;

   --  What an input operand refers to.
   type Operand_Kind is (Named_File, Standard_Input);

   type Input_Operand is record
      Kind : Operand_Kind := Named_File;
      --  Operand text exactly as supplied; "-" for Standard_Input.
      Name : U.Unbounded_String := U.Null_Unbounded_String;
      Argument_Index : Positive := 1;
   end record;

   --  Requested terminal styling policy. This is the command-line vocabulary;
   --  Sed.Terminal maps it onto the terminal_styles policy.
   type Color_Mode is (Color_Auto, Color_Always, Color_Never);

   --  Administrative modes short-circuit before any engine work happens.
   type Invocation_Mode is (Run_Mode, Help_Mode, Version_Mode);

   type Invocation is private;

   --  @param Item Invocation to inspect.
   --  @return Run, help or version mode.
   function Mode (Item : Invocation) return Invocation_Mode;

   --  @param Item Invocation to inspect.
   --  @return True when -n was given at least once.
   function Suppress_Automatic_Output (Item : Invocation) return Boolean;

   --  @param Item Invocation to inspect.
   --  @return Requested styling policy.
   function Color (Item : Invocation) return Color_Mode;

   --  @param Item Invocation to inspect.
   --  @return True when --color was given explicitly.
   function Color_Was_Explicit (Item : Invocation) return Boolean;

   --  @param Item Invocation to inspect.
   --  @return Number of ordered script declarations.
   function Script_Count (Item : Invocation) return Natural;

   --  @param Item Invocation to inspect.
   --  @param Index 1-based position in command-line order.
   --  @return Script declaration at that position.
   function Script (Item : Invocation; Index : Positive) return Script_Declaration
     with Pre => Index <= Script_Count (Item);

   --  @param Item Invocation to inspect.
   --  @return Number of input operands.
   function Operand_Count (Item : Invocation) return Natural;

   --  @param Item Invocation to inspect.
   --  @param Index 1-based position in command-line order.
   --  @return Input operand at that position.
   function Operand (Item : Invocation; Index : Positive) return Input_Operand
     with Pre => Index <= Operand_Count (Item);

   --  Result of parsing or validating an argument list.
   type Parse_Result is private;

   --  @param Item Result to inspect.
   --  @return True when the argument list produced a usable invocation.
   function Succeeded (Item : Parse_Result) return Boolean;

   --  @param Item Successful result.
   --  @return The structured invocation.
   function Value (Item : Parse_Result) return Invocation
     with Pre => Succeeded (Item);

   --  @param Item Failed result.
   --  @return The structured failure diagnostic.
   function Failure (Item : Parse_Result) return Sed.Diagnostics.Diagnostic
     with Pre => not Succeeded (Item);

   --  Intermediate result of token parsing, before semantic validation.
   --
   --  Token parsing recognizes options and collects operands but does not
   --  decide whether the first operand is a script, or whether a script was
   --  supplied at all. Those are validation questions.
   type Token_Parse is private;

   --  @param Item Token parse to inspect.
   --  @return True when no malformed token was found.
   function Succeeded (Item : Token_Parse) return Boolean;

   --  @param Item Failed token parse.
   --  @return The structured failure diagnostic.
   function Failure (Item : Token_Parse) return Sed.Diagnostics.Diagnostic
     with Pre => not Succeeded (Item);

   --  @param Item Token parse to inspect.
   --  @return True when at least one -e or -f option was present.
   function Has_Script_Option (Item : Token_Parse) return Boolean;

   --  @param Item Token parse to inspect.
   --  @return Number of operands that were not consumed as option arguments.
   function Pending_Operand_Count (Item : Token_Parse) return Natural;

   --  Styling settings recognized before parsing stopped.
   --
   --  These are available even when parsing failed, so that a --color given
   --  before a malformed option still governs how that failure is rendered.
   --
   --  @param Item Token parse to inspect.
   --  @return Requested styling policy.
   function Color (Item : Token_Parse) return Color_Mode;

   --  @param Item Token parse to inspect.
   --  @return True when --color was given explicitly.
   function Color_Was_Explicit (Item : Token_Parse) return Boolean;

private

   package Script_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Script_Declaration);

   package Operand_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Input_Operand);

   --  An operand as seen by token parsing: still just text plus its position.
   type Raw_Operand is record
      Text : U.Unbounded_String := U.Null_Unbounded_String;
      Argument_Index : Positive := 1;
   end record;

   package Raw_Operand_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Raw_Operand);

   type Invocation is record
      Mode : Invocation_Mode := Run_Mode;
      Suppress : Boolean := False;
      Color : Color_Mode := Color_Auto;
      Color_Explicit : Boolean := False;
      Scripts : Script_Vectors.Vector := Script_Vectors.Empty_Vector;
      Operands : Operand_Vectors.Vector := Operand_Vectors.Empty_Vector;
   end record;

   type Parse_Result is record
      Ok : Boolean := False;
      Item : Invocation;
      Diagnostic : Sed.Diagnostics.Diagnostic :=
        Sed.Diagnostics.Make (Sed.Diagnostics.Internal_Error);
   end record;

   type Token_Parse is record
      Ok : Boolean := False;
      Diagnostic : Sed.Diagnostics.Diagnostic :=
        Sed.Diagnostics.Make (Sed.Diagnostics.Internal_Error);
      Mode : Invocation_Mode := Run_Mode;
      Suppress : Boolean := False;
      Color : Color_Mode := Color_Auto;
      Color_Explicit : Boolean := False;
      Script_Option_Seen : Boolean := False;
      Scripts : Script_Vectors.Vector := Script_Vectors.Empty_Vector;
      Operands : Raw_Operand_Vectors.Vector := Raw_Operand_Vectors.Empty_Vector;
   end record;

end Sed.Command_Line;

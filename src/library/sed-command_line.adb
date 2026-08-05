package body Sed.Command_Line is

   ----------
   -- Mode --
   ----------

   function Mode (Item : Invocation) return Invocation_Mode is
   begin
      return Item.Mode;
   end Mode;

   -------------------------------
   -- Suppress_Automatic_Output --
   -------------------------------

   function Suppress_Automatic_Output (Item : Invocation) return Boolean is
   begin
      return Item.Suppress;
   end Suppress_Automatic_Output;

   -----------
   -- Color --
   -----------

   function Color (Item : Invocation) return Color_Mode is
   begin
      return Item.Color;
   end Color;

   --------------------------
   -- Color_Was_Explicit --
   --------------------------

   function Color_Was_Explicit (Item : Invocation) return Boolean is
   begin
      return Item.Color_Explicit;
   end Color_Was_Explicit;

   ------------------
   -- Script_Count --
   ------------------

   function Script_Count (Item : Invocation) return Natural is
   begin
      return Natural (Item.Scripts.Length);
   end Script_Count;

   ------------
   -- Script --
   ------------

   function Script (Item : Invocation; Index : Positive) return Script_Declaration is
   begin
      return Item.Scripts (Index);
   end Script;

   -------------------
   -- Operand_Count --
   -------------------

   function Operand_Count (Item : Invocation) return Natural is
   begin
      return Natural (Item.Operands.Length);
   end Operand_Count;

   -------------
   -- Operand --
   -------------

   function Operand (Item : Invocation; Index : Positive) return Input_Operand is
   begin
      return Item.Operands (Index);
   end Operand;

   ---------------
   -- Succeeded --
   ---------------

   function Succeeded (Item : Parse_Result) return Boolean is
   begin
      return Item.Ok;
   end Succeeded;

   -----------
   -- Value --
   -----------

   function Value (Item : Parse_Result) return Invocation is
   begin
      return Item.Item;
   end Value;

   -------------
   -- Failure --
   -------------

   function Failure (Item : Parse_Result) return Sed.Diagnostics.Diagnostic is
   begin
      return Item.Diagnostic;
   end Failure;

   ---------------
   -- Succeeded --
   ---------------

   function Succeeded (Item : Token_Parse) return Boolean is
   begin
      return Item.Ok;
   end Succeeded;

   -------------
   -- Failure --
   -------------

   function Failure (Item : Token_Parse) return Sed.Diagnostics.Diagnostic is
   begin
      return Item.Diagnostic;
   end Failure;

   -------------------------
   -- Has_Script_Option --
   -------------------------

   function Has_Script_Option (Item : Token_Parse) return Boolean is
   begin
      return Item.Script_Option_Seen;
   end Has_Script_Option;

   ------------------------------
   -- Pending_Operand_Count --
   ------------------------------

   function Pending_Operand_Count (Item : Token_Parse) return Natural is
   begin
      return Natural (Item.Operands.Length);
   end Pending_Operand_Count;

   -----------
   -- Color --
   -----------

   function Color (Item : Token_Parse) return Color_Mode is
   begin
      return Item.Color;
   end Color;

   --------------------------
   -- Color_Was_Explicit --
   --------------------------

   function Color_Was_Explicit (Item : Token_Parse) return Boolean is
   begin
      return Item.Color_Explicit;
   end Color_Was_Explicit;

end Sed.Command_Line;

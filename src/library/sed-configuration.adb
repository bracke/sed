package body Sed.Configuration is

   package CL renames Sed.Command_Line;
   package T renames Sed.Terminal;

   --  Map the command-line colour vocabulary onto the terminal vocabulary.
   function Choice_Of (Mode : CL.Color_Mode) return T.Color_Choice
     is (case Mode is
           when CL.Color_Auto   => T.Automatic,
           when CL.Color_Always => T.Always,
           when CL.Color_Never  => T.Never);

   -----------------
   -- Error_Style --
   -----------------

   function Error_Style
     (Choice : CL.Color_Mode;
      Explicit : Boolean;
      Context : Sed.Environment.Process_Environment)
      return T.Style_Policy is
   begin
      return T.Resolve
        (Choice => Choice_Of (Choice),
         Explicit => Explicit,
         Destination_Is_Terminal => Context.Standard_Error_Is_Terminal,
         No_Color => Context.No_Color);
   end Error_Style;

   -------------
   -- Resolve --
   -------------

   function Resolve
     (Invocation : CL.Invocation;
      Context : Sed.Environment.Process_Environment) return Settings
   is
      Choice : constant T.Color_Choice := Choice_Of (CL.Color (Invocation));
      Explicit : constant Boolean := CL.Color_Was_Explicit (Invocation);
   begin
      return
        (Mode => CL.Mode (Invocation),
         Suppress => CL.Suppress_Automatic_Output (Invocation),
         Output =>
           T.Resolve
             (Choice => Choice,
              Explicit => Explicit,
              Destination_Is_Terminal => Context.Standard_Output_Is_Terminal,
              No_Color => Context.No_Color),
         Errors =>
           T.Resolve
             (Choice => Choice,
              Explicit => Explicit,
              Destination_Is_Terminal => Context.Standard_Error_Is_Terminal,
              No_Color => Context.No_Color));
   end Resolve;

   ----------
   -- Mode --
   ----------

   function Mode (Item : Settings) return CL.Invocation_Mode is
   begin
      return Item.Mode;
   end Mode;

   -------------------------------
   -- Suppress_Automatic_Output --
   -------------------------------

   function Suppress_Automatic_Output (Item : Settings) return Boolean is
   begin
      return Item.Suppress;
   end Suppress_Automatic_Output;

   ------------------
   -- Output_Style --
   ------------------

   function Output_Style (Item : Settings) return T.Style_Policy is
   begin
      return Item.Output;
   end Output_Style;

   -----------------
   -- Error_Style --
   -----------------

   function Error_Style (Item : Settings) return T.Style_Policy is
   begin
      return Item.Errors;
   end Error_Style;

end Sed.Configuration;

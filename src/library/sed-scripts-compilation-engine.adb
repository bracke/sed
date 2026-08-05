package body Sed.Scripts.Compilation.Engine is

   ----------------
   -- Program_Of --
   ----------------

   function Program_Of (Item : Compiled_Program) return Sedlib.Programs.Program is
   begin
      return Item.Program;
   end Program_Of;

end Sed.Scripts.Compilation.Engine;

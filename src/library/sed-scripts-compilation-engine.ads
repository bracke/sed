with Sedlib.Programs;

--  Access to the compiled engine program.
--
--  Only the execution adapter needs the sedlib program itself. Keeping the
--  accessor in a separate child means Sed.Scripts.Compilation's own interface
--  stays free of engine types, and any unit that reaches for the raw program
--  has to name this package to do it.
package Sed.Scripts.Compilation.Engine is

   --  @param Item Compiled program wrapper.
   --  @return The engine program to execute.
   function Program_Of (Item : Compiled_Program) return Sedlib.Programs.Program
     with Pre => Is_Valid (Item);

end Sed.Scripts.Compilation.Engine;

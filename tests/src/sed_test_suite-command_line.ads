with AUnit.Test_Cases;

package Sed_Test_Suite.Command_Line is
   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (Test : Test_Case) return AUnit.Message_String;

   overriding procedure Register_Tests (Test : in out Test_Case);
end Sed_Test_Suite.Command_Line;

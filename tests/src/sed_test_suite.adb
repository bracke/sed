with Sed_Test_Suite.Command_Line;
with Sed_Test_Suite.Conformance;
with Sed_Test_Suite.Robustness;
with Sed_Test_Suite.Scripts;

package body Sed_Test_Suite is

   -----------
   -- Suite --
   -----------

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      --  Registration order is fixed so that a run is reproducible and a
      --  failure always appears at the same position in the report.
      Result.Add_Test (new Sed_Test_Suite.Command_Line.Test_Case);
      Result.Add_Test (new Sed_Test_Suite.Scripts.Test_Case);
      Result.Add_Test (new Sed_Test_Suite.Conformance.Test_Case);
      Result.Add_Test (new Sed_Test_Suite.Robustness.Test_Case);
      return Result;
   end Suite;

end Sed_Test_Suite;

with AUnit.Test_Suites;

--  Root of the sed test suite.
--
--  Test identifiers are stable and appear in every registered routine name, so
--  a requirement in doc/posix-conformance.md can be traced to the exact case
--  that pins it and a failure names the requirement it broke.
package Sed_Test_Suite is

   --  Build the complete suite in a fixed, deterministic order.
   --
   --  @return Suite holding every mandatory test case.
   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Sed_Test_Suite;

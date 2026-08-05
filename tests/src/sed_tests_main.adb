with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with Sed_Test_Suite;

--  Runner for the sed test suite.
--
--  The report is plain by default: a test run is machine-read as often as it
--  is looked at, and styling would only get in the way. Any failing mandatory
--  test makes the process exit non-zero.
procedure Sed_Tests_Main is

   use type AUnit.Status;

   function Runner is new AUnit.Run.Test_Runner_With_Status (Sed_Test_Suite.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status : AUnit.Status;

begin
   Status := Runner (Reporter);

   if Status = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Sed_Tests_Main;

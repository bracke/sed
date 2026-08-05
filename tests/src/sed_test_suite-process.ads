with AUnit.Test_Cases;

--  Process-level tests.
--
--  Every other suite drives Sed.Application.Execute in-process with injected
--  substitutes. These tests run the built executable as a real process
--  instead, so what they cover is exactly what in-process tests cannot: the
--  argument vector as the shell hands it over, the real standard streams,
--  environment variables, the catalogue resolved relative to the executable,
--  files actually created on disk, and the process exit status the operating
--  system reports.
--
--  Each case runs in its own directory under the test crate's object tree, so
--  nothing is written outside the workspace and one case cannot see another's
--  files.
package Sed_Test_Suite.Process is
   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (Test : Test_Case) return AUnit.Message_String;

   overriding procedure Register_Tests (Test : in out Test_Case);
end Sed_Test_Suite.Process;

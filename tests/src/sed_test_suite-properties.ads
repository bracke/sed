with AUnit.Test_Cases;

--  Property tests over deterministically generated input.
--
--  The cases elsewhere pin specific behaviour against specific bytes. These
--  assert relationships that must hold for *any* input, and check them over
--  generated data that reaches shapes nobody writes by hand: empty lines,
--  runs of them, a final line with no newline, bytes outside ASCII, an
--  embedded NUL.
--
--  Every property is self-evident without an oracle -- a script that must
--  reproduce its input, an operation that must undo itself, an invariant a
--  substitution must leave behind -- so a failure is unambiguous rather than
--  a disagreement with a reference implementation.
--
--  Generation is a seeded sequence with fixed seeds, so a failure reproduces
--  exactly and the suite never varies between runs.
package Sed_Test_Suite.Properties is
   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding function Name (Test : Test_Case) return AUnit.Message_String;

   overriding procedure Register_Tests (Test : in out Test_Case);
end Sed_Test_Suite.Properties;

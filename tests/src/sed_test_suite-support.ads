with Ada.Strings.Unbounded;
with Sed.Environment;
with Sed.Status;
with Sed_Test_Suite.Doubles;

--  Harness that drives the real application from a test.
--
--  Every case goes through Sed.Application.Execute, the same entry point the
--  process main uses, with in-memory streams and an in-memory filesystem
--  injected. There is no second execution path for tests to drift away from.
package Sed_Test_Suite.Support is

   package U renames Ada.Strings.Unbounded;

   type Argument_Array is array (Positive range <>) of U.Unbounded_String;

   No_Arguments : constant Argument_Array (1 .. 0) := [others => <>];

   --  @param Item Argument text.
   --  @return Argument value for an Argument_Array aggregate.
   function A (Item : String) return U.Unbounded_String;

   type Run_Result is record
      Output : U.Unbounded_String := U.Null_Unbounded_String;
      Errors : U.Unbounded_String := U.Null_Unbounded_String;
      Outcome : Sed.Status.Outcome := Sed.Status.Success;
      Exit_Status : Sed.Status.Exit_Status := 0;
   end record;

   --  Run sed against an in-memory environment.
   --
   --  @param Arguments Command-line arguments, without the program name.
   --  @param Files Filesystem the run reads and writes through.
   --  @param Standard_Input Bytes standard input delivers.
   --  @param Locale Requested locale; empty selects the catalogue default.
   --  @param Error_Is_Terminal Whether standard error reports a terminal.
   --  @return Captured output, diagnostics and status.
   function Run
     (Arguments : Argument_Array;
      Files : in out Doubles.Memory_Filesystem;
      Standard_Input : String := "";
      Locale : String := "";
      Error_Is_Terminal : Boolean := False) return Run_Result;

   --  Run sed with a filesystem that holds nothing.
   --
   --  @param Arguments Command-line arguments, without the program name.
   --  @param Standard_Input Bytes standard input delivers.
   --  @param Locale Requested locale; empty selects the catalogue default.
   --  @return Captured output, diagnostics and status.
   function Run
     (Arguments : Argument_Array;
      Standard_Input : String := "";
      Locale : String := "") return Run_Result;

   --  @param Item Result to inspect.
   --  @return Everything written to standard output.
   function Output (Item : Run_Result) return String;

   --  @param Item Result to inspect.
   --  @return Everything written to standard error.
   function Errors (Item : Run_Result) return String;

   --  @param Haystack Text to search.
   --  @param Needle Text to look for.
   --  @return True when Needle occurs in Haystack.
   function Contains (Haystack : String; Needle : String) return Boolean;

   --  The process environment tests use by default.
   --
   --  It resolves the maintained catalogue from the repository so that
   --  localization is exercised for real rather than through a stub.
   --
   --  @param Locale Requested locale.
   --  @param Error_Is_Terminal Whether standard error reports a terminal.
   --  @return Environment value.
   function Environment
     (Locale : String := "";
      Error_Is_Terminal : Boolean := False)
      return Sed.Environment.Process_Environment;

   --  @return Path of the maintained message catalogue, or an empty string.
   function Catalog_Path return String;

end Sed_Test_Suite.Support;

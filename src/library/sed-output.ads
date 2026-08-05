--  Vocabulary shared by the output destinations.
--
--  sed writes two kinds of bytes: the program's own data, which goes to
--  standard output and to w destinations untouched, and diagnostics, which go
--  to standard error through the message catalogue. Only the first kind
--  passes through this hierarchy, which is why nothing here knows about
--  locales or styling.
package Sed.Output is

   pragma Pure;

   --  Whether a written line carries its newline.
   --
   --  A final input line that had no newline is written back without one, so
   --  that byte-exact round-tripping is possible; every other line keeps its
   --  terminator.
   type Terminator_Policy is (With_Terminator, Without_Terminator);

   --  @param Terminated True when the line carried a terminator.
   --  @return Matching policy value.
   function Policy_For (Terminated : Boolean) return Terminator_Policy
     is (if Terminated then With_Terminator else Without_Terminator);

end Sed.Output;

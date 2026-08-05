--  Semantic validation of a token parse.
--
--  Token parsing knows which words were options; validation knows what the
--  remaining words mean. The single POSIX rule it enforces is that the first
--  operand is the script exactly when no -e and no -f option was given.
package Sed.Command_Line.Validation is

   --  Turn a token parse into a usable invocation or a structured failure.
   --
   --  A failed token parse is passed through unchanged, so the first problem
   --  found on the command line is the one reported.
   --
   --  @param Item Token parse produced by Sed.Command_Line.Options.Parse.
   --  @return Validated invocation, or the structured failure.
   function Validate (Item : Token_Parse) return Parse_Result;

end Sed.Command_Line.Validation;

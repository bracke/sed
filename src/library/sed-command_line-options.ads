with Ada.Strings.Bounded;
with Sed.Command_Line.Arguments;

--  Authoritative option registry and token parsing.
--
--  Every option the program accepts has exactly one descriptor here. The
--  parser recognizes nothing that is not in the table, so an unsupported GNU
--  option is an unknown option rather than a silent alias, and help output is
--  generated from the same table that drives parsing.
--
--  Token parsing recognizes options and collects operands. It does not decide
--  whether the first operand is the script; that is validation's job.
package Sed.Command_Line.Options is

   type Option_Id is
     (Quiet_Option,
      Expression_Option,
      Script_File_Option,
      Help_Option,
      Version_Option,
      Color_Option);

   type Option_Form is (Short_Option, Long_Option);

   type Argument_Requirement is (No_Argument, Required_Argument);

   --  Whether POSIX mandates the option or it is an implementation-defined
   --  administrative addition. Conformance documentation is generated from
   --  this classification.
   type Conformance_Class is (POSIX_Option, Implementation_Option);

   Max_Spelling_Length : constant := 16;
   Max_Key_Length      : constant := 64;

   package Spellings is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max_Spelling_Length);

   package Keys is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max_Key_Length);

   type Option_Descriptor is record
      --  Spelling including leading hyphens, for example "-e" or "--color".
      Spelling : Spellings.Bounded_String;
      Form : Option_Form;
      Requirement : Argument_Requirement;
      --  True when the argument may be attached, as in -e'p' or --color=never.
      --  Short options additionally allow the argument in the next word.
      Attachment_Allowed : Boolean;
      Conformance : Conformance_Class;
      --  Message key of the help line describing this option.
      Help_Key : Keys.Bounded_String;
      --  Administrative mode the option selects, or Run_Mode when it does not
      --  select one.
      Selects_Mode : Invocation_Mode;
   end record;

   --  @param Id Option to describe.
   --  @return The single authoritative descriptor for that option.
   function Descriptor (Id : Option_Id) return Option_Descriptor;

   --  @param Id Option to describe.
   --  @return Spelling including leading hyphens.
   function Spelling (Id : Option_Id) return String
     with Post => Spelling'Result'Length in 2 .. Max_Spelling_Length;

   --  @param Id Option to describe.
   --  @return Message key of the option's help line.
   function Help_Key (Id : Option_Id) return String;

   --  Parse an argument list into options, script declarations and operands.
   --
   --  Parsing stops as soon as an administrative option is recognized, so
   --  --help and --version never cause later arguments to be interpreted.
   --  A malformed token yields a structured failure and no invocation.
   --
   --  @param List Injected argument list.
   --  @return Token parse holding either the recognized tokens or a failure.
   function Parse (List : Arguments.Argument_List'Class) return Token_Parse;

end Sed.Command_Line.Options;

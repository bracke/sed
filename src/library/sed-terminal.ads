--  Terminal styling policy for diagnostics and administrative output.
--
--  Styling is presentation only. It never reaches sed data, never reaches a w
--  destination, never changes which message is selected, never changes a
--  diagnostic's meaning and never changes process status. A styled and an
--  unstyled diagnostic carry exactly the same plain text.
--
--  The policy is resolved once from the requested colour mode, whether the
--  destination is a terminal, and the NO_COLOR convention. An explicit
--  --color always wins over the environment, because the user asking for a
--  particular behaviour outranks a convention that guesses at it.
package Sed.Terminal is

   --  Requested styling behaviour, independent of the command-line spelling.
   type Color_Choice is (Automatic, Always, Never);

   --  Parts of a rendered diagnostic that may be styled independently.
   type Element is
     (Program_Name_Element,
      Error_Element,
      Warning_Element,
      Information_Element,
      Location_Element,
      Option_Element,
      Heading_Element);

   type Style_Policy is private;

   Plain : constant Style_Policy;

   --  Decide whether output to a particular destination should be styled.
   --
   --  @param Choice Requested colour mode.
   --  @param Explicit True when --color was given on the command line.
   --  @param Destination_Is_Terminal True when the destination is a terminal.
   --  @param No_Color True when the NO_COLOR convention is active.
   --  @return Resolved styling policy.
   function Resolve
     (Choice : Color_Choice;
      Explicit : Boolean;
      Destination_Is_Terminal : Boolean;
      No_Color : Boolean) return Style_Policy
     with Post =>
       (if Choice = Never then not Enabled (Resolve'Result))
       and then (if Choice = Always and then Explicit
                 then Enabled (Resolve'Result))
       and then (if Choice = Automatic and then not Destination_Is_Terminal
                 then not Enabled (Resolve'Result));

   --  @param Policy Policy to inspect.
   --  @return True when styling should be emitted.
   function Enabled (Policy : Style_Policy) return Boolean;

   --  Return Item decorated for the given element, or unchanged.
   --
   --  @param Policy Resolved styling policy.
   --  @param Item Plain text to decorate.
   --  @param Part Diagnostic element the text belongs to.
   --  @return Decorated text when styling is enabled, otherwise Item.
   function Style
     (Policy : Style_Policy;
      Item : String;
      Part : Element) return String
     with Post => (if not Enabled (Policy) then Style'Result = Item);

private

   type Style_Policy is record
      Active : Boolean := False;
   end record;

   Plain : constant Style_Policy := (Active => False);

end Sed.Terminal;

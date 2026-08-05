with Terminal_Styles;

package body Sed.Terminal is

   --  Map a diagnostic element to a terminal_styles semantic role.
   function Role_Of (Part : Element) return Terminal_Styles.Style_Role
     is (case Part is
           when Program_Name_Element => Terminal_Styles.Role_Muted,
           when Error_Element        => Terminal_Styles.Role_Error,
           when Warning_Element      => Terminal_Styles.Role_Warning,
           when Information_Element  => Terminal_Styles.Role_Info,
           when Location_Element     => Terminal_Styles.Role_Muted,
           when Option_Element       => Terminal_Styles.Role_Info,
           when Heading_Element      => Terminal_Styles.Role_Header);

   -------------
   -- Resolve --
   -------------

   function Resolve
     (Choice : Color_Choice;
      Explicit : Boolean;
      Destination_Is_Terminal : Boolean;
      No_Color : Boolean) return Style_Policy is
   begin
      case Choice is
         when Never =>
            return (Active => False);

         when Always =>
            --  An explicit request outranks NO_COLOR; the same value reached
            --  by default does not.
            return (Active => Explicit or else not No_Color);

         when Automatic =>
            return
              (Active => Destination_Is_Terminal and then not No_Color);
      end case;
   end Resolve;

   -------------
   -- Enabled --
   -------------

   function Enabled (Policy : Style_Policy) return Boolean is
   begin
      return Policy.Active;
   end Enabled;

   -----------
   -- Style --
   -----------

   function Style
     (Policy : Style_Policy;
      Item : String;
      Part : Element) return String is
   begin
      if not Policy.Active or else Item'Length = 0 then
         return Item;
      end if;

      --  terminal_styles keeps its emission policy process-wide. This program
      --  has already made the whole decision itself, so the library is told
      --  to emit unconditionally and is asked for the decoration only. The
      --  assignment is idempotent and carries the same value every time.
      Terminal_Styles.Set_Color_Policy (Terminal_Styles.Color_Always);

      return Terminal_Styles.Decorate
        (Item => Item,
         Role => Role_Of (Part),
         Destination_Is_Terminal => True);
   end Style;

end Sed.Terminal;

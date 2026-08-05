package body Sed.Command_Line.Arguments is

   ------------
   -- Append --
   ------------

   procedure Append (Self : in out Fixed_List; Text : String) is
   begin
      Self.Items.Append (Text);
   end Append;

   -----------
   -- Count --
   -----------

   overriding function Count (Self : Fixed_List) return Natural is
   begin
      return Natural (Self.Items.Length);
   end Count;

   --------------
   -- Argument --
   --------------

   overriding function Argument (Self : Fixed_List; Index : Positive) return String is
   begin
      return Self.Items (Index);
   end Argument;

end Sed.Command_Line.Arguments;

package body Sed.Input.Cursor
  with SPARK_Mode => On
is

   --------------------
   -- Begin_Sequence --
   --------------------

   procedure Begin_Sequence (Item : in out Position) is
   begin
      Item.Index := 1;
      Item.Opened := False;
   end Begin_Sequence;

   ----------
   -- Open --
   ----------

   procedure Open (Item : in out Position) is
   begin
      Item.Opened := True;
   end Open;

   -------------
   -- Advance --
   -------------

   procedure Advance (Item : in out Position) is
   begin
      Item.Index := Item.Index + 1;
      Item.Opened := False;
   end Advance;

end Sed.Input.Cursor;

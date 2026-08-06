package body Sed.Input.Delivery
  with SPARK_Mode => On
is

   ------------
   -- Assign --
   ------------

   procedure Assign (Item : in out Counters) is
   begin
      Item.Assigned := Item.Assigned + 1;
   end Assign;

   -------------
   -- Deliver --
   -------------

   procedure Deliver (Item : in out Counters; Final : Boolean) is
   begin
      Item.Delivered := Item.Delivered + 1;
      Item.Final_Seen := Final;
   end Deliver;

end Sed.Input.Delivery;

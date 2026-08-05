package body Sed.Status is

   ---------------
   -- Status_Of --
   ---------------

   function Status_Of (Value : Outcome) return Exit_Status is
   begin
      return
        (case Value is
           when Success            => 0,
           when Processing_Failure => 1,
           when Invocation_Failure => 2,
           when Internal_Failure   => 3);
   end Status_Of;

   -------------
   -- Initial --
   -------------

   function Initial return Accumulator is
   begin
      return (Value => Success);
   end Initial;

   --------------------
   -- Record_Outcome --
   --------------------

   procedure Record_Outcome (Item : in out Accumulator; Value : Outcome) is
   begin
      if Value > Item.Value then
         Item.Value := Value;
      end if;
   end Record_Outcome;

   -------------
   -- Current --
   -------------

   function Current (Item : Accumulator) return Outcome is
   begin
      return Item.Value;
   end Current;

   ------------
   -- Failed --
   ------------

   function Failed (Item : Accumulator) return Boolean is
   begin
      return Item.Value /= Success;
   end Failed;

   ---------------
   -- Status_Of --
   ---------------

   function Status_Of (Item : Accumulator) return Exit_Status is
   begin
      return Status_Of (Item.Value);
   end Status_Of;

end Sed.Status;

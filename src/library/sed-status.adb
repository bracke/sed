package body Sed.Status
  with SPARK_Mode => On
is

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

   --------------------
   -- Record_Outcome --
   --------------------

   procedure Record_Outcome (Item : in out Accumulator; Value : Outcome) is
   begin
      if Value > Item.Value then
         Item.Value := Value;
      end if;
   end Record_Outcome;

end Sed.Status;

package body Sed.Scripts.Layout
  with SPARK_Mode => On
is

   -------------
   -- Unit_At --
   -------------

   function Unit_At
     (Items : Placement_Array;
      Offset : Natural) return Natural is
   begin
      if Items'Length = 0 then
         return 0;
      end if;

      for Index in Items'Range loop
         if Offset < Items (Index).Start_Offset + Items (Index).Span then
            return Index;
         end if;

         --  Every unit up to this one ended at or before Offset.
         --
         --  Two things follow, and both are needed. Entering the next
         --  iteration, contiguity turns "the previous unit ended at or
         --  before Offset" into "this one starts at or before it", which is
         --  the returned result's lower bound. And when the loop runs out,
         --  the same fact for the final unit says Offset is past the end of
         --  the whole script, which is what makes returning the last unit
         --  the answer the postcondition asks for.
         --
         --  It sits after the test rather than before it because a loop
         --  invariant has to be one contiguous sequence, and it cannot be
         --  split around the return.
         pragma Loop_Invariant
           (for all Earlier in Items'First .. Index =>
              Offset >= Items (Earlier).Start_Offset + Items (Earlier).Span);
      end loop;

      --  Reaching here means the loop ran out, so the invariant holds for the
      --  final unit: Offset is at or past where it ends, which by contiguity
      --  is the end of the whole script.
      pragma Assert
        (Offset >= Items (Items'Last).Start_Offset + Items (Items'Last).Span);
      pragma Assert (Offset >= Total_Span (Items));

      --  Past the end of every unit: the final one owns it.
      return Items'Last;
   end Unit_At;

   --------------------
   -- Offset_Within --
   --------------------

   function Offset_Within
     (Items : Placement_Array;
      Index : Positive;
      Offset : Natural) return Natural is
   begin
      return Offset - Items (Index).Start_Offset;
   end Offset_Within;

end Sed.Scripts.Layout;

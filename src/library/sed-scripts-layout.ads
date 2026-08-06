--  The arithmetic behind the source map.
--
--  Script sources are laid out one after another in the combined script, and
--  a diagnostic is attributed to a source by asking which unit a byte offset
--  falls in. Getting that wrong does not fail loudly: it reports a real error
--  against the wrong -e expression or the wrong line of a -f file, which is
--  worse than no location at all.
--
--  The layout is separated from Sed.Scripts so that it can be proved. What is
--  left here is pure arithmetic over a placement table -- no strings, no
--  containers -- which is what makes SPARK applicable at all; the text and
--  the vector that hold the sources stay outside the proof scope, where they
--  belong.
--
--  The invariant the whole thing rests on is that units tile the combined
--  script exactly: the first starts at zero, each subsequent one starts where
--  its predecessor ended, and none is empty. Sed.Scripts establishes that by
--  construction, and Unit_At is proved correct under it.
package Sed.Scripts.Layout
  with SPARK_Mode => On
is

   --  Where one source unit sits in the combined script.
   type Placement is record
      --  0-based offset of the unit's first byte.
      Start_Offset : Natural := 0;
      --  Bytes the unit occupies, including the newline that separates it
      --  from the next. Never zero: a unit always ends with a newline, so it
      --  always occupies at least one byte.
      Span : Positive := 1;
      --  1-based line on which the unit begins.
      Start_Line : Positive_Line_Number := 1;
      --  Lines the unit occupies. Never zero, for the same reason as Span.
      Line_Span : Positive_Line_Number := 1;
   end record;

   type Placement_Array is array (Positive range <>) of Placement;

   --  Whether the units tile the combined script without gap or overlap.
   --
   --  The bound on each element is part of the property rather than a
   --  separate assumption: without it the sums below could overflow, and a
   --  proof that ignored that would be proving something weaker than it
   --  appears to.
   function Is_Contiguous (Items : Placement_Array) return Boolean
     is (for all Index in Items'Range =>
           Items (Index).Start_Offset <= Natural'Last - Items (Index).Span
           and then
             (if Index = Items'First
              then Items (Index).Start_Offset = 0
              else Items (Index - 1).Start_Offset
                     <= Natural'Last - Items (Index - 1).Span
                   and then Items (Index).Start_Offset
                            = Items (Index - 1).Start_Offset
                              + Items (Index - 1).Span));

   --  Whether line numbers follow the same tiling as offsets.
   function Lines_Are_Consistent (Items : Placement_Array) return Boolean
     is (for all Index in Items'Range =>
           Items (Index).Start_Line
             <= Positive_Line_Number'Last - Items (Index).Line_Span
           and then
             (if Index = Items'First
              then Items (Index).Start_Line = 1
              else Items (Index - 1).Start_Line
                     <= Positive_Line_Number'Last - Items (Index - 1).Line_Span
                   and then Items (Index).Start_Line
                            = Items (Index - 1).Start_Line
                              + Items (Index - 1).Line_Span));

   --  Total bytes the units occupy.
   function Total_Span (Items : Placement_Array) return Natural
     is (if Items'Length = 0
         then 0
         else Items (Items'Last).Start_Offset + Items (Items'Last).Span)
     with Pre => Is_Contiguous (Items);

   --  The unit a byte offset falls in, or zero when there are none.
   --
   --  An offset at or past the end belongs to the final unit: the engine
   --  reports an unexpected end of script that way, and attributing it to the
   --  last source the user wrote is the only useful answer.
   function Unit_At
     (Items : Placement_Array;
      Offset : Natural) return Natural
     with
       Pre => Is_Contiguous (Items),
       --  The offset lies inside the unit returned, or it lies past the end
       --  of the script and the final unit is returned. Stated this way
       --  rather than as a case split on Total_Span: the two are equivalent
       --  here, because units tile the script and so no unit ends past its
       --  end, but proving that equivalence needs an induction over the
       --  array, and it buys a caller nothing. What a caller relies on is
       --  exactly the disjunction below.
       Post =>
         (if Items'Length = 0
          then Unit_At'Result = 0
          else Unit_At'Result in Items'Range
               and then Items (Unit_At'Result).Start_Offset <= Offset
               and then
                 (Offset < Items (Unit_At'Result).Start_Offset
                           + Items (Unit_At'Result).Span
                  or else Unit_At'Result = Items'Last));

   --  How far into its own unit an offset lies.
   function Offset_Within
     (Items : Placement_Array;
      Index : Positive;
      Offset : Natural) return Natural
     with
       Pre => Is_Contiguous (Items)
              and then Index in Items'Range
              and then Items (Index).Start_Offset <= Offset,
       Post => Offset_Within'Result = Offset - Items (Index).Start_Offset;

end Sed.Scripts.Layout;

--  The operand cursor of the logical input stream.
--
--  Operands are visited in order, opened only when the stream first needs to
--  read from them, and left behind for good once they are done -- whether
--  they were exhausted, empty, or could not be opened at all. Three things
--  have to hold and none of them is visible from reading the loop that does
--  it: an operand is never opened twice, the cursor never goes backwards, and
--  the walk always ends.
--
--  Sed.Input.Logical_Stream cannot be proved: it owns file handles, a buffer
--  and a vector. What is separated out here is the position alone, so those
--  three properties become contracts. The stream holds a cursor and drives
--  it, so they constrain the code that actually runs.
--
--  Lazy opening is a behavioural requirement, not just tidiness: an early q
--  must not open files the script never reads, and a blocking special file
--  must not be touched until the stream genuinely needs it. Requiring an
--  unopened operand in order to open one is what pins that down.
package Sed.Input.Cursor
  with SPARK_Mode => On
is

   --  One short of the whole range, so that the exhausted position one past
   --  the final operand is always representable. Operands come from the
   --  argument vector, so any real count is far below this.
   subtype Operand_Count is Natural range 0 .. Natural'Last - 1;

   type Position is record
      --  Operands in the sequence.
      Count : Operand_Count := 0;
      --  Zero before the walk starts, then 1 .. Count, then Count + 1 once
      --  every operand has been left behind.
      Index : Natural := 0;
      --  Whether the operand at Index has been opened.
      Opened : Boolean := False;
   end record;

   --  Whether the cursor is sitting on an operand.
   function Has_Current (Item : Position) return Boolean
     is (Item.Index >= 1 and then Item.Index <= Item.Count);

   --  Whether every operand has been left behind.
   function Exhausted (Item : Position) return Boolean
     is (Item.Index > Item.Count);

   --  What must hold of a cursor at every point.
   --
   --  The open flag belongs to the operand under the cursor, so it cannot be
   --  set when there is none: that is what makes "opened at most once"
   --  survive an advance rather than leaking to the next operand.
   function Is_Valid (Item : Position) return Boolean
     is (Item.Index <= Item.Count + 1
         and then (if not Has_Current (Item) then not Item.Opened));

   --  A cursor over Count operands, before the first.
   function Starting (Count : Operand_Count) return Position
     is ((Count => Count, Index => 0, Opened => False));

   --  Move to the first operand, or straight past the end when there are
   --  none.
   procedure Begin_Sequence (Item : in out Position)
     with
       Pre => Is_Valid (Item) and then Item.Index = 0,
       Post => Is_Valid (Item)
               and then Item.Index = 1
               and then not Item.Opened
               and then Item.Count = Item.Count'Old;

   --  Open the operand under the cursor.
   --
   --  Requiring it to be unopened is the whole point: an operand cannot be
   --  opened a second time, and one that was never reached cannot be opened
   --  at all.
   procedure Open (Item : in out Position)
     with
       Pre => Is_Valid (Item)
              and then Has_Current (Item)
              and then not Item.Opened,
       Post => Is_Valid (Item)
               and then Item.Opened
               and then Item.Index = Item.Index'Old
               and then Item.Count = Item.Count'Old;

   --  Leave the current operand behind, whatever became of it.
   --
   --  The index strictly increases and is bounded by Count + 1, so the walk
   --  cannot revisit an operand and cannot go on for ever.
   procedure Advance (Item : in out Position)
     with
       Pre => Is_Valid (Item) and then Has_Current (Item),
       Post => Is_Valid (Item)
               and then Item.Index = Item.Index'Old + 1
               and then Item.Index <= Item.Count + 1
               and then not Item.Opened
               and then Item.Count = Item.Count'Old;

end Sed.Input.Cursor;

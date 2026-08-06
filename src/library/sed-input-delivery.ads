--  The delivery protocol of the logical input stream.
--
--  The stream reads one record ahead so that it can say whether the record it
--  is about to hand over is the last one in the whole operand sequence. That
--  lookahead is where the stream's two counting invariants can go wrong, and
--  both are silent when they do: a global line number that repeats or skips
--  misreports every later diagnostic and every = command, and a second line
--  marked final makes $ match twice.
--
--  Sed.Input.Logical_Stream itself cannot be proved: it owns file handles,
--  unbounded buffers and a vector of operands. What is separated out here is
--  the counting alone -- no I/O, no storage -- so the protocol can be stated
--  as contracts and checked. The stream holds one of these and drives it, so
--  the rules apply to the code that actually runs rather than to a model of
--  it kept alongside.
--
--  The protocol is: a record read from a source is Assigned the next global
--  number, and a record handed to the caller is Delivered. Delivery requires
--  a record that has been assigned and not yet delivered, and cannot happen
--  at all once the final line has gone out.
package Sed.Input.Delivery
  with SPARK_Mode => On
is

   type Counters is record
      --  Records handed to the caller.
      Delivered : Line_Number := 0;
      --  Global line numbers issued. Never fewer than Delivered: a record is
      --  numbered when it is read, which is always before it is handed over.
      Assigned : Line_Number := 0;
      --  Whether the record marked as the last of the stream has gone out.
      Final_Seen : Boolean := False;
   end record;

   --  What must hold of the counters at every point.
   function Is_Valid (Item : Counters) return Boolean
     is (Item.Delivered <= Item.Assigned
         and then (if Item.Final_Seen then Item.Delivered >= 1));

   Start : constant Counters :=
     (Delivered => 0, Assigned => 0, Final_Seen => False);

   --  Whether another record may be handed over.
   --
   --  False once the final line has gone out, which is what makes "exactly
   --  one delivered line is final" enforceable rather than merely intended.
   function Can_Deliver (Item : Counters) return Boolean
     is (not Item.Final_Seen and then Item.Delivered < Item.Assigned);

   --  A record was read from a source and given the next global number.
   procedure Assign (Item : in out Counters)
     with
       Pre => Is_Valid (Item) and then Item.Assigned < Line_Number'Last,
       Post => Is_Valid (Item)
               and then Item.Assigned = Item.Assigned'Old + 1
               and then Item.Delivered = Item.Delivered'Old
               and then Item.Final_Seen = Item.Final_Seen'Old;

   --  A record was handed to the caller.
   --
   --  Final says whether it was the last of the whole stream. Requiring
   --  Can_Deliver is what rules out a second final line and a delivery of a
   --  record that was never read.
   procedure Deliver (Item : in out Counters; Final : Boolean)
     with
       Pre => Is_Valid (Item) and then Can_Deliver (Item),
       Post => Is_Valid (Item)
               and then Item.Delivered = Item.Delivered'Old + 1
               and then Item.Assigned = Item.Assigned'Old
               and then Item.Final_Seen = Final;

end Sed.Input.Delivery;

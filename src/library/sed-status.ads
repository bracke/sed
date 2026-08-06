--  Monotonic process-status accumulation.
--
--  Every subsystem reports an outcome; the application layer folds those
--  outcomes into a single accumulator and is the only layer permitted to turn
--  the result into a process exit status.
--
--  Accumulation is monotonic by construction: the enumeration is ordered by
--  precedence and Record_Outcome keeps the maximum, so a later success can
--  never erase an earlier failure.
package Sed.Status
  with SPARK_Mode => On
is

   --  Process outcome kinds, in increasing precedence order.
   type Outcome is
     (Success,
      Processing_Failure,
      Invocation_Failure,
      Internal_Failure);

   --  Stable process exit statuses.
   --
   --  0 success, help or version; 1 script loading, compilation, input,
   --  output or execution failure; 2 invalid invocation; 3 unexpected
   --  internal failure.
   type Exit_Status is range 0 .. 3;

   --  Map an outcome to its documented process exit status.
   --
   --  @param Value Outcome to map.
   --  @return Stable exit status for that outcome.
   function Status_Of (Value : Outcome) return Exit_Status
     with Post =>
       (case Value is
          when Success            => Status_Of'Result = 0,
          when Processing_Failure => Status_Of'Result = 1,
          when Invocation_Failure => Status_Of'Result = 2,
          when Internal_Failure   => Status_Of'Result = 3);

   type Accumulator is private;

   --  A fresh accumulator that reports success.
   --
   --  @return Accumulator holding Success.
   function Initial return Accumulator
     with Post => Current (Initial'Result) = Success;

   --  Fold an outcome into the accumulator, keeping the higher precedence.
   --
   --  @param Item Accumulator to update.
   --  @param Value Outcome observed by a subsystem.
   procedure Record_Outcome (Item : in out Accumulator; Value : Outcome)
     --  Monotonicity: the result is the maximum of the previous outcome and
     --  the reported one, so an earlier failure can never be erased.
     with Post => Current (Item) = Outcome'Max (Current (Item)'Old, Value);

   --  The highest-precedence outcome recorded so far.
   --
   --  @param Item Accumulator to inspect.
   --  @return Current aggregate outcome.
   function Current (Item : Accumulator) return Outcome;

   --  Whether any failure has been recorded.
   --
   --  @param Item Accumulator to inspect.
   --  @return True when the aggregate outcome is not Success.
   function Failed (Item : Accumulator) return Boolean
     with Post => Failed'Result = (Current (Item) /= Success);

   --  The exit status the process should report for this accumulator.
   --
   --  @param Item Accumulator to inspect.
   --  @return Stable exit status.
   function Status_Of (Item : Accumulator) return Exit_Status
     with Post => Status_Of'Result = Status_Of (Current (Item));

private

   type Accumulator is record
      Value : Outcome := Success;
   end record;

   --  Completed here rather than in the body so that proof can see through
   --  them. A prover given only the private declaration cannot relate Current
   --  to the field it reads, and every postcondition written in terms of
   --  Current then becomes unprovable; as expression functions they are
   --  transparent, and the monotonicity contract on Record_Outcome follows.
   function Initial return Accumulator
     is ((Value => Success));

   function Current (Item : Accumulator) return Outcome
     is (Item.Value);

   function Failed (Item : Accumulator) return Boolean
     is (Item.Value /= Success);

   function Status_Of (Item : Accumulator) return Exit_Status
     is (Status_Of (Item.Value));

end Sed.Status;

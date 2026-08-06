with AUnit.Assertions;
with Ada.Strings.Unbounded;
with Sed.Status;
with Sed_Test_Suite.Support;

package body Sed_Test_Suite.Properties is

   use AUnit.Assertions;
   use Sed_Test_Suite.Support;

   package U renames Ada.Strings.Unbounded;

   use type Sed.Status.Exit_Status;

   LF : constant Character := ASCII.LF;

   overriding function Name (Test : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (Test);
   begin
      return AUnit.Format ("sed properties");
   end Name;

   type Seed_Value is mod 2 ** 32;

   --  Fixed seeds, so a failure is reproducible and a run never varies.
   Seeds : constant array (1 .. 6) of Seed_Value :=
     [16#0000_0001#, 16#0000_2026#, 16#5EED_1234#,
      16#ABCD_EF01#, 16#DEAD_BEEF#, 16#0F0F_0F0F#];

   --  A linear congruential step. The constants are the ones Numerical
   --  Recipes uses; any full-period generator would do, since what matters
   --  is that the sequence is fixed rather than that it is random.
   procedure Advance (State : in out Seed_Value);

   --  Build an input whose shape is driven by the seed.
   function Generated_Input
     (Seed : Seed_Value;
      Terminated : Boolean) return String;

   --  Whether Text contains Item.
   function Holds (Text : String; Item : Character) return Boolean;

   --  Count the newlines in Text.
   function Newlines (Text : String) return Natural;

   -------------
   -- Advance --
   -------------

   procedure Advance (State : in out Seed_Value) is
   begin
      State := State * 1_664_525 + 1_013_904_223;
   end Advance;

   ---------------------
   -- Generated_Input --
   ---------------------

   function Generated_Input
     (Seed : Seed_Value;
      Terminated : Boolean) return String
   is
      --  A small alphabet, so generated patterns actually match often enough
      --  for a substitution property to be exercised rather than skipped.
      --  The last three reach past ASCII, past the printable range, and to a
      --  NUL, which is where a byte-exact claim usually breaks first.
      Alphabet : constant String :=
        "aabbcc  " & LF & LF & "xyz." & ASCII.HT
        & Character'Val (16#C3#) & Character'Val (16#A9#)
        & Character'Val (16#00#);

      State : Seed_Value := Seed;
      Length : Natural;
      Result : U.Unbounded_String;
   begin
      Advance (State);
      Length := Natural (State mod 120);

      for Index in 1 .. Length loop
         Advance (State);
         U.Append
           (Result,
            Alphabet
              (Alphabet'First + Natural (State mod Seed_Value (Alphabet'Length))));
      end loop;

      if Terminated and then U.Length (Result) > 0
        and then U.Element (Result, U.Length (Result)) /= LF
      then
         U.Append (Result, LF);
      end if;

      return U.To_String (Result);
   end Generated_Input;

   -----------
   -- Holds --
   -----------

   function Holds (Text : String; Item : Character) return Boolean is
   begin
      for Value of Text loop
         if Value = Item then
            return True;
         end if;
      end loop;

      return False;
   end Holds;

   ---------------
   -- Newlines --
   ---------------

   function Newlines (Text : String) return Natural is
      Count : Natural := 0;
   begin
      for Value of Text loop
         if Value = LF then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Newlines;

   --  Run a script over generated input and return what it produced.
   function Apply (Script : String; Input : String) return String;

   --  As Apply, but with automatic printing suppressed.
   function Quietly (Script : String; Input : String) return String;

   --------------
   -- Quietly --
   --------------

   function Quietly (Script : String; Input : String) return String is
      Result : constant Run_Result :=
        Run ([A ("-n"), A ("--"), A (Script)], Input);
   begin
      Assert
        (Result.Exit_Status = 0,
         "the quiet script ran cleanly: " & Script & ", diagnostics: "
         & Errors (Result));
      return Output (Result);
   end Quietly;

   -----------
   -- Apply --
   -----------

   function Apply (Script : String; Input : String) return String is
      Result : constant Run_Result := Run ([A ("--"), A (Script)], Input);
   begin
      Assert
        (Result.Exit_Status = 0,
         "the script ran cleanly: " & Script & ", diagnostics: "
         & Errors (Result));
      return Output (Result);
   end Apply;

   --  PROP-IDENTITY-001: scripts that must reproduce their input exactly.

   procedure Identity_Scripts_Reproduce_Input
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      for Seed of Seeds loop
         for Terminated in Boolean loop
            declare
               Input : constant String := Generated_Input (Seed, Terminated);
               Label : constant String :=
                 " (seed" & Seed_Value'Image (Seed)
                 & ", terminated " & Boolean'Image (Terminated) & ")";
            begin
               --  An empty script prints each line unchanged.
               Assert
                 (Apply ("", Input) = Input,
                  "PROP-IDENTITY-001 an empty script is the identity" & Label);

               --  Replacing a whole line with itself changes nothing, which
               --  also exercises & through arbitrary bytes.
               Assert
                 (Apply ("s/.*/&/", Input) = Input,
                  "PROP-IDENTITY-001 replacing a line by itself" & Label);

               --  A round trip through the hold space must come back.
               Assert
                 (Apply ("h;s/.*/REPLACED/;g", Input) = Input,
                  "PROP-IDENTITY-001 a hold space round trip" & Label);
            end;
         end loop;
      end loop;
   end Identity_Scripts_Reproduce_Input;

   --  PROP-INVOLUTION-001: operations that must undo themselves.

   procedure Operations_Undo_Themselves
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      for Seed of Seeds loop
         for Terminated in Boolean loop
            declare
               Input : constant String := Generated_Input (Seed, Terminated);
               Label : constant String :=
                 " (seed" & Seed_Value'Image (Seed)
                 & ", terminated " & Boolean'Image (Terminated) & ")";
            begin
               --  Swapping two characters twice restores the original.
               Assert
                 (Apply ("y/ab/ba/", Apply ("y/ab/ba/", Input)) = Input,
                  "PROP-INVOLUTION-001 transliteration is its own inverse"
                  & Label);
            end;
         end loop;

         --  Reversing twice restores the original. Only for input that ends
         --  in a newline: reversal moves the final line, and a file whose
         --  last line lacks one legitimately gains it.
         declare
            Input : constant String := Generated_Input (Seed, True);
            Reverse_Script : constant String := "1!G;h;$!d";
         begin
            Assert
              (Apply (Reverse_Script, Apply (Reverse_Script, Input)) = Input,
               "PROP-INVOLUTION-001 reversing twice restores the order (seed"
               & Seed_Value'Image (Seed) & ")");
         end;
      end loop;
   end Operations_Undo_Themselves;

   --  PROP-SUBST-001: what a global substitution must leave behind.

   procedure Global_Substitution_Invariants
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      for Seed of Seeds loop
         for Terminated in Boolean loop
            declare
               Input : constant String := Generated_Input (Seed, Terminated);
               Label : constant String :=
                 " (seed" & Seed_Value'Image (Seed)
                 & ", terminated " & Boolean'Image (Terminated) & ")";
               Replaced : constant String := Apply ("s/a/Z/g", Input);
            begin
               --  Nothing the pattern matched may survive, since the
               --  replacement cannot reintroduce it.
               Assert
                 (not Holds (Replaced, 'a'),
                  "PROP-SUBST-001 a global substitution leaves no match"
                  & Label);

               --  A substitution that cannot match a newline cannot change
               --  how many lines there are.
               Assert
                 (Newlines (Replaced) = Newlines (Input),
                  "PROP-SUBST-001 a global substitution preserves line count"
                  & Label);

               --  Applying it again must change nothing further.
               Assert
                 (Apply ("s/a/Z/g", Replaced) = Replaced,
                  "PROP-SUBST-001 a global substitution is idempotent" & Label);

               --  Length cannot change when replacing one byte with one byte.
               Assert
                 (Replaced'Length = Input'Length,
                  "PROP-SUBST-001 a one-for-one substitution preserves length"
                  & Label);
            end;
         end loop;
      end loop;
   end Global_Substitution_Invariants;

   --  PROP-STREAM-001: what the stream itself must guarantee.

   procedure Stream_Invariants
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      for Seed of Seeds loop
         for Terminated in Boolean loop
            declare
               Input : constant String := Generated_Input (Seed, Terminated);
               Label : constant String :=
                 " (seed" & Seed_Value'Image (Seed)
                 & ", terminated " & Boolean'Image (Terminated) & ")";
               --  A final line with no newline is the only line that can
               --  lack one, so it is the only correction the counts need.
               Unterminated : constant Boolean :=
                 Input'Length > 0 and then Input (Input'Last) /= LF;

               Lines : constant Natural :=
                 (if Input'Length = 0 then 0
                  else Newlines (Input) + (if Unterminated then 1 else 0));
            begin
               --  Deleting everything produces nothing at all.
               Assert
                 (Apply ("d", Input) = "",
                  "PROP-STREAM-001 deleting every line produces no output"
                  & Label);

               --  Printing each line and then printing it again doubles the
               --  stream. When the last line had no newline, the first of
               --  its two copies gains the separator it was missing, which
               --  is the single extra byte.
               Assert
                 (Apply ("p", Input)'Length
                    = 2 * Input'Length + (if Unterminated then 1 else 0),
                  "PROP-STREAM-001 printing every line twice doubles the stream"
                  & Label);

               --  = emits exactly one number, on its own line, per line the
               --  stream delivered.
               Assert
                 (Newlines (Quietly ("=", Input)) = Lines,
                  "PROP-STREAM-001 = emits one number per delivered line"
                  & Label);
            end;
         end loop;
      end loop;
   end Stream_Invariants;

   overriding procedure Register_Tests (Test : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (Test, Identity_Scripts_Reproduce_Input'Access,
         "PROP-IDENTITY-001 identity scripts");
      Register_Routine
        (Test, Operations_Undo_Themselves'Access,
         "PROP-INVOLUTION-001 self-inverse operations");
      Register_Routine
        (Test, Global_Substitution_Invariants'Access,
         "PROP-SUBST-001 global substitution invariants");
      Register_Routine
        (Test, Stream_Invariants'Access,
         "PROP-STREAM-001 stream invariants");
   end Register_Tests;

end Sed_Test_Suite.Properties;

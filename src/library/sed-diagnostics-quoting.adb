with Ada.Strings.Unbounded;

package body Sed.Diagnostics.Quoting is

   package U renames Ada.Strings.Unbounded;

   Hex_Digits : constant String := "0123456789ABCDEF";

   --  Length of the well-formed UTF-8 sequence starting at Index, or zero.
   --
   --  Overlong encodings, surrogate halves and values above U+10FFFF are
   --  rejected, because a permissive decoder here would let a crafted path
   --  smuggle bytes past the escaper.
   function Sequence_Length (Value : String; Index : Positive) return Natural;

   --  @param Item Byte to render.
   --  @return Two-digit uppercase hexadecimal representation.
   function Hex_Pair (Item : Character) return String;

   ---------------------
   -- Sequence_Length --
   ---------------------

   function Sequence_Length (Value : String; Index : Positive) return Natural is

      function Is_Continuation (Position : Positive) return Boolean is
        (Position <= Value'Last
         and then Character'Pos (Value (Position)) in 16#80# .. 16#BF#);

      Lead : constant Natural := Character'Pos (Value (Index));

   begin
      if Lead in 16#C2# .. 16#DF# then
         if Is_Continuation (Index + 1) then
            return 2;
         end if;

      elsif Lead in 16#E0# .. 16#EF# then
         if Is_Continuation (Index + 1) and then Is_Continuation (Index + 2) then
            declare
               Second : constant Natural := Character'Pos (Value (Index + 1));
            begin
               --  Reject overlong three-byte forms and UTF-16 surrogates.
               if Lead = 16#E0# and then Second < 16#A0# then
                  return 0;
               elsif Lead = 16#ED# and then Second > 16#9F# then
                  return 0;
               else
                  return 3;
               end if;
            end;
         end if;

      elsif Lead in 16#F0# .. 16#F4# then
         if Is_Continuation (Index + 1)
           and then Is_Continuation (Index + 2)
           and then Is_Continuation (Index + 3)
         then
            declare
               Second : constant Natural := Character'Pos (Value (Index + 1));
            begin
               --  Reject overlong four-byte forms and code points above
               --  U+10FFFF.
               if Lead = 16#F0# and then Second < 16#90# then
                  return 0;
               elsif Lead = 16#F4# and then Second > 16#8F# then
                  return 0;
               else
                  return 4;
               end if;
            end;
         end if;
      end if;

      return 0;
   end Sequence_Length;

   --------------
   -- Hex_Pair --
   --------------

   function Hex_Pair (Item : Character) return String is
      Code : constant Natural := Character'Pos (Item);
   begin
      return [Hex_Digits (Code / 16 + 1), Hex_Digits (Code mod 16 + 1)];
   end Hex_Pair;

   ------------
   -- Escape --
   ------------

   function Escape (Value : String) return String is
      Result : U.Unbounded_String;
      Index  : Positive := Value'First;
      Span   : Natural;
   begin
      while Index <= Value'Last loop
         declare
            Item : constant Character := Value (Index);
            Code : constant Natural := Character'Pos (Item);
         begin
            case Item is
               when '\'           => U.Append (Result, "\\");
               when ASCII.LF      => U.Append (Result, "\n");
               when ASCII.CR      => U.Append (Result, "\r");
               when ASCII.HT      => U.Append (Result, "\t");
               when ASCII.BEL     => U.Append (Result, "\a");
               when ASCII.BS      => U.Append (Result, "\b");
               when ASCII.FF      => U.Append (Result, "\f");
               when ASCII.VT      => U.Append (Result, "\v");
               when ASCII.ESC     => U.Append (Result, "\e");
               when ASCII.NUL     => U.Append (Result, "\0");

               when others =>
                  if Code in 16#20# .. 16#7E# then
                     U.Append (Result, Item);

                  elsif Code < 16#80# then
                     --  Remaining C0 controls and DEL.
                     U.Append (Result, "\x" & Hex_Pair (Item));

                  else
                     Span := Sequence_Length (Value, Index);

                     if Span = 0 then
                        U.Append (Result, "\x" & Hex_Pair (Item));
                     else
                        U.Append (Result, Value (Index .. Index + Span - 1));
                        Index := Index + Span - 1;
                     end if;
                  end if;
            end case;
         end;

         Index := Index + 1;
      end loop;

      return U.To_String (Result);
   end Escape;

   ------------
   -- Quoted --
   ------------

   function Quoted (Value : String) return String is
      Escaped : constant String := Escape (Value);
      Result  : U.Unbounded_String;
   begin
      U.Append (Result, ''');

      for Item of Escaped loop
         if Item = ''' then
            --  Keep the delimiter unambiguous inside the quoted value.
            U.Append (Result, "\'");
         else
            U.Append (Result, Item);
         end if;
      end loop;

      U.Append (Result, ''');
      return U.To_String (Result);
   end Quoted;

   -------------
   -- Is_Safe --
   -------------

   function Is_Safe (Value : String) return Boolean is
   begin
      return Escape (Value) = Value;
   end Is_Safe;

end Sed.Diagnostics.Quoting;

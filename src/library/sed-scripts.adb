with Sed.Scripts.Layout;

package body Sed.Scripts is

   --  Count newline bytes in Value.
   function Newline_Count (Value : String) return Line_Number;

   -------------------
   -- Newline_Count --
   -------------------

   function Newline_Count (Value : String) return Line_Number is
      Total : Line_Number := 0;
   begin
      for Item of Value loop
         if Item = ASCII.LF then
            Total := Total + 1;
         end if;
      end loop;

      return Total;
   end Newline_Count;

   ------------
   -- Append --
   ------------

   procedure Append
     (Set : in out Source_Set;
      Kind : Source_Kind;
      Content : String;
      Path : String := "";
      Occurrence : Positive := 1;
      Argument_Index : Positive := 1;
      Ordinal : Positive := 1;
      Positional : Boolean := False)
   is
      Start_Offset : constant Natural := U.Length (Set.Text);
      Start_Line : constant Positive_Line_Number := Set.Next_Line;

      --  A unit that does not end with a newline gets one, so the next unit
      --  starts at column one and cannot be absorbed into this one.
      Needs_Separator : constant Boolean :=
        Content'Length = 0 or else Content (Content'Last) /= ASCII.LF;

      Item : Source_Unit;
   begin
      U.Append (Set.Text, Content);

      if Needs_Separator then
         U.Append (Set.Text, ASCII.LF);
      end if;

      Item :=
        (Id             => Source_Id (Natural (Set.Units.Length) + 1),
         Kind           => Kind,
         Path           => U.To_Unbounded_String (Path),
         Occurrence     => Occurrence,
         Argument_Index => Argument_Index,
         Ordinal        => Ordinal,
         Positional     => Positional,
         Content        => U.To_Unbounded_String (Content),
         Start_Offset   => Start_Offset,
         Span           => U.Length (Set.Text) - Start_Offset,
         Start_Line     => Start_Line,
         Line_Span      =>
           Newline_Count (Content) + (if Needs_Separator then 1 else 0));

      Set.Units.Append (Item);
      Set.Next_Line := Start_Line + Item.Line_Span;
   end Append;

   -----------
   -- Count --
   -----------

   function Count (Set : Source_Set) return Natural is
   begin
      return Natural (Set.Units.Length);
   end Count;

   ----------
   -- Unit --
   ----------

   function Unit (Set : Source_Set; Index : Positive) return Source_Unit is
   begin
      return Set.Units (Index);
   end Unit;

   -------------------
   -- Combined_Text --
   -------------------

   function Combined_Text (Set : Source_Set) return String is
   begin
      return U.To_String (Set.Text);
   end Combined_Text;

   -------------
   -- Unit_At --
   -------------

   function Unit_At (Set : Source_Set; Offset : Natural) return Natural is
      Count : constant Natural := Natural (Set.Units.Length);
   begin
      if Count = 0 then
         return 0;
      end if;

      --  The search itself is proved in Sed.Scripts.Layout, over a placement
      --  table rather than over the vector and text that hold the sources.
      --  Building that table here is what lets the arithmetic that decides
      --  which -e expression a diagnostic names be machine-checked, while
      --  the containers stay outside the proof scope.
      declare
         Placements : Layout.Placement_Array (1 .. Count);
      begin
         for Index in 1 .. Count loop
            declare
               Item : Source_Unit renames Set.Units (Index);
            begin
               Placements (Index) :=
                 (Start_Offset => Item.Start_Offset,
                  Span => Item.Span,
                  Start_Line => Item.Start_Line,
                  Line_Span => Line_Number'Max (1, Item.Line_Span));
            end;
         end loop;

         --  Append maintains the tiling, so the precondition holds; the
         --  assertion says so where a reader can see it.
         pragma Assert (Layout.Is_Contiguous (Placements));

         return Layout.Unit_At (Placements, Offset);
      end;
   end Unit_At;

   ------------
   -- Locate --
   ------------

   function Locate
     (Set : Source_Set;
      Offset : Natural) return Sed.Diagnostics.Source_Location
   is
      Index : constant Natural := Unit_At (Set, Offset);
   begin
      if Index = 0 then
         return Sed.Diagnostics.No_Location_Value;
      end if;

      declare
         Item : Source_Unit renames Set.Units (Index);
         Content : constant String := U.To_String (Item.Content);

         --  Offset inside this unit's own content, clamped so that an offset
         --  pointing at the synthesized separator reports the end of the
         --  unit rather than running past it.
         Local : constant Natural :=
           Natural'Min
             ((if Offset >= Item.Start_Offset
               then Offset - Item.Start_Offset
               else 0),
              Content'Length);

         Line : Positive_Line_Number := 1;
         Column : Positive_Line_Number := 1;
      begin
         for Position in 1 .. Local loop
            if Content (Content'First + Position - 1) = ASCII.LF then
               Line := Line + 1;
               Column := 1;
            else
               Column := Column + 1;
            end if;
         end loop;

         case Item.Kind is
            when Script_File =>
               return Sed.Diagnostics.Path_At
                 (Path   => U.To_String (Item.Path),
                  Line   => Line,
                  Column => Column);

            when Inline_Expression =>
               return Sed.Diagnostics.Expression_At
                 (Occurrence => Item.Occurrence,
                  Line       => Line,
                  Column     => Column);
         end case;
      end;
   end Locate;

end Sed.Scripts;

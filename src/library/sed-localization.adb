with Messages.Result;

package body Sed.Localization is

   use type Messages.Result.Render_Status;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Item : in out Catalog;
      Catalog_Path : String;
      Locale : String) is
   begin
      Item.Locale := U.To_Unbounded_String (Locale);
      Item.Valid := False;

      if Catalog_Path'Length = 0 then
         return;
      end if;

      Messages.Runtime.Initialize (Item.Runtime, Catalog_Path);
      Item.Valid := Messages.Runtime.Is_Valid (Item.Runtime);

   exception
      when others =>
         --  A catalogue the host cannot read leaves the adapter invalid; that
         --  is reported by rendering keys, not by propagating an exception
         --  out of program start-up.
         Item.Valid := False;
   end Initialize;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (Item : Catalog) return Boolean is
   begin
      return Item.Valid;
   end Is_Valid;

   ------------
   -- Locale --
   ------------

   function Locale (Item : Catalog) return String is
   begin
      return U.To_String (Item.Locale);
   end Locale;

   ---------
   -- Set --
   ---------

   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : String) is
   begin
      Messages.Arguments.Set (Args.Values, Name, Value);
   end Set;

   ---------
   -- Set --
   ---------

   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : Line_Count) is
   begin
      Messages.Arguments.Set_Integer
        (Args.Values, Name, Long_Long_Integer (Value));
   end Set;

   ----------
   -- Text --
   ----------

   function Text (Item : Catalog; Key : String) return String is
      Empty : Parameters;
   begin
      return Text (Item, Key, Empty);
   end Text;

   ----------
   -- Text --
   ----------

   function Text
     (Item : Catalog;
      Key : String;
      Args : Parameters) return String is
   begin
      if not Item.Valid then
         return Key;
      end if;

      declare
         Result : constant Messages.Result.Render_Result :=
           Messages.Runtime.Render
             (Item => Item.Runtime,
              Locale => U.To_String (Item.Locale),
              Key => Key,
              Arguments => Args.Values);
      begin
         if Result.Status = Messages.Result.Success then
            return Messages.Result.Output_Text (Result.Text);
         end if;

         return Key;
      end;

   exception
      when others =>
         return Key;
   end Text;

   -------------
   -- Has_Key --
   -------------

   function Has_Key (Item : Catalog; Key : String) return Boolean is
      Empty : Parameters;
   begin
      if not Item.Valid then
         return False;
      end if;

      declare
         Result : constant Messages.Result.Render_Result :=
           Messages.Runtime.Render
             (Item => Item.Runtime,
              Locale => U.To_String (Item.Locale),
              Key => Key,
              Arguments => Empty.Values);
      begin
         --  A message whose template needs arguments still resolves; only an
         --  unknown key fails to resolve at all.
         return Result.Status /= Messages.Result.Missing_Key;
      end;

   exception
      when others =>
         return False;
   end Has_Key;

end Sed.Localization;

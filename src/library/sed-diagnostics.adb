with Sed.Diagnostics.Registry;

package body Sed.Diagnostics is

   -------------
   -- Path_At --
   -------------

   function Path_At
     (Path   : String;
      Line   : Line_Number := 0;
      Column : Line_Number := 0) return Source_Location is
   begin
      return
        (Kind       => Path_Location,
         Path       => U.To_Unbounded_String (Path),
         Occurrence => 0,
         Line       => Line,
         Column     => Column);
   end Path_At;

   -------------------
   -- Expression_At --
   -------------------

   function Expression_At
     (Occurrence : Positive;
      Line       : Line_Number := 0;
      Column     : Line_Number := 0) return Source_Location is
   begin
      return
        (Kind       => Expression_Location,
         Path       => U.Null_Unbounded_String,
         Occurrence => Occurrence,
         Line       => Line,
         Column     => Column);
   end Expression_At;

   ----------
   -- Make --
   ----------

   function Make
     (Code     : Diagnostic_Code;
      Location : Source_Location := No_Location_Value;
      Related  : Source_Location := No_Location_Value) return Diagnostic is
   begin
      return
        (Code_Value => Code,
         Location   => Location,
         Related    => Related,
         Supplied   => No_Parameters,
         Texts      => [others => U.Null_Unbounded_String],
         Numbers    => [others => 0]);
   end Make;

   ---------
   -- Set --
   ---------

   procedure Set
     (Item : in out Diagnostic;
      Name : Text_Parameter;
      Text : String) is
   begin
      Item.Texts (Name) := U.To_Unbounded_String (Text);
      Item.Supplied (Name) := True;
   end Set;

   ---------
   -- Set --
   ---------

   procedure Set
     (Item   : in out Diagnostic;
      Name   : Integer_Parameter;
      Number : Line_Count) is
   begin
      Item.Numbers (Name) := Number;
      Item.Supplied (Name) := True;
   end Set;

   ----------
   -- Code --
   ----------

   function Code (Item : Diagnostic) return Diagnostic_Code is
   begin
      return Item.Code_Value;
   end Code;

   -----------------
   -- Severity_Of --
   -----------------

   function Severity_Of (Item : Diagnostic) return Severity is
   begin
      return Registry.Descriptor (Item.Code_Value).Severity;
   end Severity_Of;

   -----------------------
   -- Recoverability_Of --
   -----------------------

   function Recoverability_Of (Item : Diagnostic) return Recoverability is
   begin
      return Registry.Descriptor (Item.Code_Value).Recoverability;
   end Recoverability_Of;

   ------------------
   -- Subsystem_Of --
   ------------------

   function Subsystem_Of (Item : Diagnostic) return Subsystem is
   begin
      return Registry.Descriptor (Item.Code_Value).Owner;
   end Subsystem_Of;

   -------------------
   -- Status_Effect --
   -------------------

   function Status_Effect (Item : Diagnostic) return Sed.Status.Outcome is
   begin
      return Registry.Descriptor (Item.Code_Value).Status_Effect;
   end Status_Effect;

   -----------------
   -- Location_Of --
   -----------------

   function Location_Of (Item : Diagnostic) return Source_Location is
   begin
      return Item.Location;
   end Location_Of;

   ----------------
   -- Related_Of --
   ----------------

   function Related_Of (Item : Diagnostic) return Source_Location is
   begin
      return Item.Related;
   end Related_Of;

   -------------
   -- Present --
   -------------

   function Present (Item : Diagnostic) return Parameter_Set is
   begin
      return Item.Supplied;
   end Present;

   -------------
   -- Text_Of --
   -------------

   function Text_Of (Item : Diagnostic; Name : Text_Parameter) return String is
   begin
      return U.To_String (Item.Texts (Name));
   end Text_Of;

   ---------------
   -- Number_Of --
   ---------------

   function Number_Of (Item : Diagnostic; Name : Integer_Parameter) return Line_Count is
   begin
      return Item.Numbers (Name);
   end Number_Of;

   -----------------------
   -- Schema_Satisfied --
   -----------------------

   function Schema_Satisfied (Item : Diagnostic) return Boolean is
      Required : constant Parameter_Set :=
        Registry.Descriptor (Item.Code_Value).Required;
      Accepted : constant Parameter_Set := Registry.Accepted (Item.Code_Value);
   begin
      for Name in Parameter_Name loop
         if Required (Name) and then not Item.Supplied (Name) then
            return False;
         end if;

         if Item.Supplied (Name) and then not Accepted (Name) then
            return False;
         end if;
      end loop;

      return True;
   end Schema_Satisfied;

   ------------
   -- Append --
   ------------

   procedure Append (List : in out Diagnostic_List; Item : Diagnostic) is
   begin
      List.Items.Append (Item);
   end Append;

   --------------
   -- Contains --
   --------------

   function Contains (List : Diagnostic_List; Item : Diagnostic) return Boolean is
   begin
      for Existing of List.Items loop
         if Existing = Item then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   -------------------
   -- Append_Unique --
   -------------------

   procedure Append_Unique (List : in out Diagnostic_List; Item : Diagnostic) is
   begin
      if not Contains (List, Item) then
         List.Items.Append (Item);
      end if;
   end Append_Unique;

   ------------
   -- Length --
   ------------

   function Length (List : Diagnostic_List) return Natural is
   begin
      return Natural (List.Items.Length);
   end Length;

   -------------
   -- Element --
   -------------

   function Element (List : Diagnostic_List; Index : Positive) return Diagnostic is
   begin
      return List.Items (Index);
   end Element;

   ----------------
   -- Has_Errors --
   ----------------

   function Has_Errors (List : Diagnostic_List) return Boolean is
   begin
      for Item of List.Items loop
         if Severity_Of (Item) = Error then
            return True;
         end if;
      end loop;

      return False;
   end Has_Errors;

   -------------------
   -- Status_Effect --
   -------------------

   function Status_Effect (List : Diagnostic_List) return Sed.Status.Outcome is
      use type Sed.Status.Outcome;
      Result : Sed.Status.Outcome := Sed.Status.Success;
   begin
      for Item of List.Items loop
         if Status_Effect (Item) > Result then
            Result := Status_Effect (Item);
         end if;
      end loop;

      return Result;
   end Status_Effect;

end Sed.Diagnostics;

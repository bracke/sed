private with Ada.Containers.Indefinite_Vectors;

--  Injected argument-list abstraction.
--
--  Nothing below the process adapter reads Ada.Command_Line. Parsing works
--  against this interface, so a test can drive the very same parser with a
--  synthetic argument list, and the production path differs only in who fills
--  the list.
package Sed.Command_Line.Arguments is

   type Argument_List is limited interface;

   --  @param Self Argument list to inspect.
   --  @return Number of arguments, excluding the program name.
   function Count (Self : Argument_List) return Natural is abstract;

   --  @param Self Argument list to inspect.
   --  @param Index 1-based argument position.
   --  @return Argument text exactly as supplied, with no interpretation.
   function Argument (Self : Argument_List; Index : Positive) return String
     is abstract
     with Pre'Class => Index <= Count (Self);

   --  A concrete argument list held in memory.
   --
   --  The process adapter fills one of these from Ada.Command_Line; tests fill
   --  one directly. Having a single concrete implementation keeps production
   --  and test invocations on exactly the same parsing path.
   type Fixed_List is limited new Argument_List with private;

   --  @param Self List to append to.
   --  @param Text Argument text to append.
   procedure Append (Self : in out Fixed_List; Text : String)
     with Post => Count (Self) = Count (Self)'Old + 1;

   overriding function Count (Self : Fixed_List) return Natural;

   overriding function Argument (Self : Fixed_List; Index : Positive) return String;

private

   package Text_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Fixed_List is limited new Argument_List with record
      Items : Text_Vectors.Vector := Text_Vectors.Empty_Vector;
   end record;

end Sed.Command_Line.Arguments;

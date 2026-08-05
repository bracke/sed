--  Real standard input, standard output and standard error.
--
--  This is the process adapter for the three standard streams. It is the only
--  place that touches them, so every other layer can be driven by in-memory
--  substitutes in tests without changing a line of production logic.
--
--  Bytes pass through untranslated. On POSIX hosts the standard streams carry
--  octets natively; see doc/input-output-model.md for the platform scope of
--  that guarantee.
package Sed.IO.Process_Streams is

   type Standard_Channel is (Output_Channel, Error_Channel);

   type Process_Output (Channel : Standard_Channel) is
     limited new Output_Stream_Interface with private;

   overriding procedure Write
     (Self : in out Process_Output;
      Data : String;
      Result : out IO_Result);

   overriding procedure Flush
     (Self : in out Process_Output;
      Result : out IO_Result);

   overriding function Is_Terminal (Self : Process_Output) return Boolean;

   type Process_Input is limited new Input_Source_Interface with private;

   overriding procedure Read
     (Self : in out Process_Input;
      Into : out String;
      Last : out Natural;
      Result : out IO_Result);

   --  Whether the given standard file descriptor refers to a terminal.
   --
   --  @param Descriptor 0 for standard input, 1 output, 2 error.
   --  @return True when the descriptor is a terminal.
   function Descriptor_Is_Terminal (Descriptor : Natural) return Boolean;

private

   type Process_Output (Channel : Standard_Channel) is
     limited new Output_Stream_Interface with null record;

   type Process_Input is limited new Input_Source_Interface with record
      --  Set once the underlying stream has reported exhaustion, so that a
      --  repeated "-" operand observes end of file instead of rewinding.
      Exhausted : Boolean := False;
   end record;

end Sed.IO.Process_Streams;

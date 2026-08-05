with Sed.Command_Line.Arguments;
with Sed.Environment;
with Sed.IO;
with Sed.Status;

--  The application layer.
--
--  This is the only layer allowed to coordinate all the others, and the only
--  one allowed to turn an outcome into a process exit status. Everything it
--  touches is injected: the argument list, the three standard streams, the
--  filesystem and the process environment. Production and tests therefore run
--  the very same code path, differing only in what they inject.
--
--  Unexpected exceptions stop here. They produce one localized internal-error
--  diagnostic and exit status 3, never an Ada traceback.
package Sed.Application is

   subtype Application_Status is Sed.Status.Outcome;

   --  Run one complete sed invocation against injected surroundings.
   --
   --  The order is fixed: parse and validate, handle help or version, load
   --  every script source, compile, create the w destinations, open the
   --  logical input stream, execute, flush, close, aggregate. Nothing opens
   --  an input operand or creates a w destination until compilation has
   --  succeeded.
   --
   --  @param Arguments Injected argument list.
   --  @param Standard_In Byte source for "-" operands.
   --  @param Standard_Out Byte sink for sed program data.
   --  @param Standard_Err Byte sink for localized diagnostics.
   --  @param Filesystem Filesystem for scripts, inputs, r and w files.
   --  @param Context Captured process environment.
   --  @return Aggregate outcome of the run.
   function Execute
     (Arguments : Sed.Command_Line.Arguments.Argument_List'Class;
      Standard_In : in out Sed.IO.Input_Source_Interface'Class;
      Standard_Out : in out Sed.IO.Output_Stream_Interface'Class;
      Standard_Err : in out Sed.IO.Output_Stream_Interface'Class;
      Filesystem : in out Sed.IO.Filesystem_Interface'Class;
      Context : Sed.Environment.Process_Environment)
      return Application_Status;

   --  Run against the real process and set the process exit status.
   --
   --  @param Status Exit status the process should report.
   procedure Run (Status : out Sed.Status.Exit_Status);

end Sed.Application;

with Ada.Command_Line;
with Sed.Application;
with Sed.Status;

--  Process entry point for the sed stream editor.
--
--  The main unit is deliberately thin: it hands control to the application
--  layer, reports the status that layer decided, and contains the last-resort
--  handler for anything the application could not contain. It is named
--  sed_main because Sed is the root package of the hierarchy; the executable
--  built from it is installed as "sed".
procedure Sed_Main is
   Status : Sed.Status.Exit_Status := Sed.Status.Status_Of
     (Sed.Status.Internal_Failure);
begin
   Sed.Application.Run (Status);
   Ada.Command_Line.Set_Exit_Status
     (Ada.Command_Line.Exit_Status (Status));
exception
   when others =>
      --  The application layer contains expected and unexpected failures
      --  alike and renders a localized internal-error diagnostic for them.
      --  Reaching here means even that failed, so the only thing left to do
      --  is report the internal-failure status without an Ada traceback.
      Ada.Command_Line.Set_Exit_Status
        (Ada.Command_Line.Exit_Status
           (Sed.Status.Status_Of (Sed.Status.Internal_Failure)));
end Sed_Main;

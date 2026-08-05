with Sed.Command_Line;
with Sed.Environment;
with Sed.Terminal;

--  The resolved, immutable run configuration.
--
--  Everything that the invocation and the environment together decide is
--  settled here once, before any work starts, and nothing changes it
--  afterwards. Later layers read settings; they never re-derive them from the
--  command line or from the environment.
package Sed.Configuration is

   type Settings is private;

   --  Resolve settings from a validated invocation and the environment.
   --
   --  @param Invocation Validated invocation.
   --  @param Context Captured process environment.
   --  @return Immutable settings for this run.
   function Resolve
     (Invocation : Sed.Command_Line.Invocation;
      Context : Sed.Environment.Process_Environment) return Settings;

   --  Resolve only the styling policy for standard error.
   --
   --  Diagnostics have to be renderable before an invocation is validated,
   --  because the first thing that can go wrong is the invocation itself.
   --
   --  @param Choice Requested colour mode recognized so far.
   --  @param Explicit True when --color was given.
   --  @param Context Captured process environment.
   --  @return Styling policy for standard error.
   function Error_Style
     (Choice : Sed.Command_Line.Color_Mode;
      Explicit : Boolean;
      Context : Sed.Environment.Process_Environment)
      return Sed.Terminal.Style_Policy;

   --  @param Item Settings to inspect.
   --  @return Run, help or version mode.
   function Mode (Item : Settings) return Sed.Command_Line.Invocation_Mode;

   --  @param Item Settings to inspect.
   --  @return True when -n was given.
   function Suppress_Automatic_Output (Item : Settings) return Boolean;

   --  @param Item Settings to inspect.
   --  @return Styling policy for standard output.
   function Output_Style (Item : Settings) return Sed.Terminal.Style_Policy;

   --  @param Item Settings to inspect.
   --  @return Styling policy for standard error.
   function Error_Style (Item : Settings) return Sed.Terminal.Style_Policy;

private

   type Settings is record
      Mode : Sed.Command_Line.Invocation_Mode := Sed.Command_Line.Run_Mode;
      Suppress : Boolean := False;
      Output : Sed.Terminal.Style_Policy := Sed.Terminal.Plain;
      Errors : Sed.Terminal.Style_Policy := Sed.Terminal.Plain;
   end record;

end Sed.Configuration;

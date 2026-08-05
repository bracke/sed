with AUnit.Assertions;
with Sed.Status;
with Sed_Test_Suite.Doubles;
with Sed_Test_Suite.Support;

package body Sed_Test_Suite.Conformance is

   use AUnit.Assertions;
   use Sed_Test_Suite.Support;

   use type Sed.Status.Exit_Status;

   LF : constant Character := ASCII.LF;

   overriding function Name (Test : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (Test);
   begin
      return AUnit.Format ("sed POSIX conformance");
   end Name;

   --  Assert that a script transforms input into the expected bytes.
   procedure Transforms
     (Script : String;
      Input : String;
      Expected : String;
      Label : String;
      Quiet : Boolean := False);

   ----------------
   -- Transforms --
   ----------------

   procedure Transforms
     (Script : String;
      Input : String;
      Expected : String;
      Label : String;
      Quiet : Boolean := False)
   is
      Result : constant Run_Result :=
        (if Quiet
         then Run ([A ("-n"), A ("--"), A (Script)], Input)
         else Run ([A ("--"), A (Script)], Input));
   begin
      Assert
        (Result.Exit_Status = 0,
         Label & " succeeds, diagnostics: " & Errors (Result));
      Assert
        (Output (Result) = Expected,
         Label & " output is [" & Output (Result) & "]");
   end Transforms;

   --  CMD-PRINT-001: p, P, = and l.

   procedure Printing_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms ("p", "a" & LF, "a" & LF & "a" & LF, "CMD-PRINT-001 p");
      Transforms ("p", "a" & LF, "a" & LF, "CMD-PRINT-001 -n p", Quiet => True);
      Transforms
        ("$!N;P;D", "a" & LF & "b" & LF, "a" & LF & "b" & LF,
         "CMD-PRINT-001 P and D");
      Transforms ("=", "a" & LF, "1" & LF & "a" & LF, "CMD-PRINT-001 =");
      Transforms
        ("l", "a" & ASCII.HT, "a\t$" & LF & "a" & ASCII.HT,
         "CMD-PRINT-001 l escapes and marks the end");
   end Printing_Commands;

   --  CMD-DELETE-001: d, D and q.

   procedure Deletion_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms ("d", "a" & LF & "b" & LF, "", "CMD-DELETE-001 d");
      Transforms
        ("2d", "a" & LF & "b" & LF & "c" & LF, "a" & LF & "c" & LF,
         "CMD-DELETE-001 addressed d");
      Transforms
        ("2q", "a" & LF & "b" & LF & "c" & LF, "a" & LF & "b" & LF,
         "CMD-DELETE-001 q stops the stream");
   end Deletion_Commands;

   --  CMD-HOLD-001: h, H, g, G and x.

   procedure Hold_Space_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      --  The classic reversing pipeline exercises h, G and the initially
      --  empty hold space together.
      Transforms
        ("1!G;h;$p", "a" & LF & "b" & LF & "c" & LF,
         "c" & LF & "b" & LF & "a" & LF,
         "CMD-HOLD-001 reverse with h and G", Quiet => True);
      --  The hold space starts as an empty line, so every route out of an
      --  untouched one yields an empty line rather than nothing.
      Transforms
        ("x", "a" & LF, String'(1 => LF),
         "CMD-HOLD-001 x with an untouched hold space prints an empty line");
      Transforms
        ("g", "a" & LF, String'(1 => LF),
         "CMD-HOLD-001 g from an untouched hold space prints an empty line");
      Transforms
        ("G", "a" & LF & "b" & LF, "a" & LF & LF & "b" & LF & LF,
         "CMD-HOLD-001 G double-spaces the input");
      Transforms
        ("1h;2H;2{g;p}", "a" & LF & "b" & LF,
         "a" & LF & "a" & LF & "b" & LF & "a" & LF & "b" & LF,
         "CMD-HOLD-001 H appends and g copies back");
   end Hold_Space_Commands;

   --  CMD-CYCLE-001: n and N.

   procedure Cycle_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("n;p", "a" & LF & "b" & LF, "b" & LF,
         "CMD-CYCLE-001 n reads the next line", Quiet => True);
      Transforms
        ("N;s/\n/+/", "a" & LF & "b" & LF, "a+b" & LF,
         "CMD-CYCLE-001 N joins two lines");
   end Cycle_Commands;

   --  CMD-TEXT-001: a, i and c in the POSIX multiline form.

   procedure Text_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("a\" & LF & "after", "x" & LF, "x" & LF & "after" & LF,
         "CMD-TEXT-001 a appends after the line");
      Transforms
        ("i\" & LF & "before", "x" & LF, "before" & LF & "x" & LF,
         "CMD-TEXT-001 i inserts before the line");
      Transforms
        ("c\" & LF & "changed", "x" & LF, "changed" & LF,
         "CMD-TEXT-001 c replaces the line");
      Transforms
        ("a\" & LF & "one\" & LF & "two", "x" & LF,
         "x" & LF & "one" & LF & "two" & LF,
         "CMD-TEXT-001 escaped newlines stay in the text");
   end Text_Commands;

   --  CMD-BRANCH-001: labels, b and t.

   procedure Branch_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        (":x;s/a/b/;tx", "aaa" & LF, "bbb" & LF,
         "CMD-BRANCH-001 t loops back while substitutions succeed");
      Transforms
        ("b;p", "a" & LF, "a" & LF,
         "CMD-BRANCH-001 a bare b skips to the end of the cycle");
      Transforms
        ("bskip;s/a/b/;:skip", "a" & LF, "a" & LF,
         "CMD-BRANCH-001 b jumps forward over commands");
      Transforms
        ("s/a/b/;ty;s/b/c/;:y", "a" & LF, "b" & LF,
         "CMD-BRANCH-001 t branches only after a successful substitution");
   end Branch_Commands;

   --  CMD-TRANSLIT-001: y.

   procedure Transliteration_Command
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("y/abc/xyz/", "abc" & LF, "xyz" & LF, "CMD-TRANSLIT-001 y maps bytes");
      Transforms
        ("y/-/_/", "a-b" & LF, "a_b" & LF,
         "CMD-TRANSLIT-001 y maps a single character");

      declare
         --  Mismatched set lengths are a compile failure, not a silent
         --  truncation.
         Result : constant Run_Result :=
           Run ([A ("--"), A ("y/ab/x/")], "ab" & LF);
      begin
         Assert
           (Result.Exit_Status = 1,
            "CMD-TRANSLIT-001 mismatched y sets fail to compile");
         Assert
           (Output (Result) = "",
            "CMD-TRANSLIT-001 a failed y produces no output");
      end;
   end Transliteration_Command;

   --  CMD-GROUP-001: command groups, negation and comments.

   procedure Grouping_And_Comments
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("/b/{p}", "a" & LF & "b" & LF, "b" & LF,
         "CMD-GROUP-001 a regular-expression address guards a group",
         Quiet => True);
      Transforms
        ("/b/!{p}", "a" & LF & "b" & LF, "a" & LF,
         "CMD-GROUP-001 negation inverts a guarded group", Quiet => True);
      Transforms
        ("2!p", "a" & LF & "b" & LF, "a" & LF,
         "CMD-GROUP-001 negation inverts a numeric address", Quiet => True);
      Transforms
        ("/a/{/b/!{p}}", "ab" & LF & "ac" & LF, "ac" & LF,
         "CMD-GROUP-001 groups nest", Quiet => True);
      Transforms
        ("#comment" & LF & "p", "a" & LF, "a" & LF,
         "CMD-GROUP-001 a comment runs to the end of its line", Quiet => True);
   end Grouping_And_Comments;

   --  ADDR-001: every POSIX address form.

   procedure Address_Forms
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Three : constant String := "one" & LF & "two" & LF & "three" & LF;
   begin
      Transforms ("1p", Three, "one" & LF, "ADDR-001 line number", Quiet => True);
      Transforms
        ("$p", Three, "three" & LF, "ADDR-001 final line", Quiet => True);
      Transforms
        ("/two/p", Three, "two" & LF, "ADDR-001 regular expression",
         Quiet => True);
      Transforms
        ("1,2p", Three, "one" & LF & "two" & LF, "ADDR-001 numeric range",
         Quiet => True);
      Transforms
        ("/two/,$p", Three, "two" & LF & "three" & LF,
         "ADDR-001 regular expression to final line", Quiet => True);
      Transforms
        ("/one/,/two/p", Three, "one" & LF & "two" & LF,
         "ADDR-001 range between two expressions", Quiet => True);
      Transforms
        ("1!p", Three, "two" & LF & "three" & LF, "ADDR-001 negated address",
         Quiet => True);
      Transforms
        ("1,2!p", Three, "three" & LF, "ADDR-001 negated range", Quiet => True);
   end Address_Forms;

   --  ADDR-002: a range reactivates later in the stream.

   procedure Range_Reactivates
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("/start/,/end/p",
         "start" & LF & "in" & LF & "end" & LF & "out" & LF
         & "start" & LF & "again" & LF & "end" & LF,
         "start" & LF & "in" & LF & "end" & LF
         & "start" & LF & "again" & LF & "end" & LF,
         "ADDR-002 a range activates again after it closes", Quiet => True);
   end Range_Reactivates;

   --  SUB-001: substitution flags and replacement syntax.

   procedure Substitution_Behaviour
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms ("s/a/X/", "aaa" & LF, "Xaa" & LF, "SUB-001 first match only");
      Transforms ("s/a/X/g", "aaa" & LF, "XXX" & LF, "SUB-001 global flag");
      Transforms
        ("s/a/X/3", "aaaa" & LF, "aaXa" & LF, "SUB-001 numeric occurrence");
      Transforms
        ("s/a/X/2g", "aaaa" & LF, "aXXX" & LF,
         "SUB-001 numeric occurrence with global");
      Transforms
        ("s/a/X/p", "a" & LF, "X" & LF, "SUB-001 print flag", Quiet => True);
      Transforms ("s/hi/[&]/", "hi" & LF, "[hi]" & LF, "SUB-001 ampersand");
      Transforms
        ("s/hi/[\&]/", "hi" & LF, "[&]" & LF,
         "SUB-001 an escaped ampersand is literal");
      Transforms
        ("s/\(a\)\(b\)/\2\1/", "ab" & LF, "ba" & LF,
         "SUB-001 replacement backreferences");
      Transforms ("s/b//", "abc" & LF, "ac" & LF, "SUB-001 empty replacement");
      Transforms
        ("s|/x/|Y|", "/x/" & LF, "Y" & LF, "SUB-001 alternate delimiter");
      Transforms
        ("s/a\/b/Y/", "a/b" & LF, "Y" & LF, "SUB-001 escaped delimiter");
      Transforms
        ("s/^a/X/;s/a$/Y/", "aba" & LF, "XbY" & LF, "SUB-001 anchors");
      Transforms
        ("s/[[:digit:]]/D/g", "a1b2" & LF, "aDbD" & LF,
         "SUB-001 bracket expression with a character class");
      Transforms ("s/z/X/", "abc" & LF, "abc" & LF, "SUB-001 no match is inert");
   end Substitution_Behaviour;

   --  SUB-002: POSIX basic regular expression syntax.
   --
   --  In a BRE the escaped forms are the operators and the bare forms are
   --  ordinary characters. Getting this backwards silently mis-executes
   --  almost every real sed script, so each direction is pinned.

   procedure Basic_Regular_Expression_Syntax
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("s/\(ab\)/[\1]/", "ab" & LF, "[ab]" & LF,
         "SUB-002 escaped parentheses group");
      Transforms
        ("s/(x)/Y/", "(x)" & LF, "Y" & LF,
         "SUB-002 bare parentheses are ordinary");
      Transforms
        ("s/a\{2\}/Y/", "aaa" & LF, "Ya" & LF, "SUB-002 escaped braces bound");
      Transforms
        ("s/a{2}/Y/", "a{2}" & LF, "Y" & LF, "SUB-002 bare braces are ordinary");
      Transforms ("s/a+/Y/", "a+" & LF, "Y" & LF, "SUB-002 plus is ordinary");
      Transforms
        ("s/a?/Y/", "a?" & LF, "Y" & LF, "SUB-002 question mark is ordinary");
      Transforms
        ("s/a|b/Y/", "a|b" & LF, "Y" & LF, "SUB-002 vertical bar is ordinary");
      Transforms
        ("s/*a/Y/", "*a" & LF, "Y" & LF,
         "SUB-002 a leading star is ordinary");
      Transforms
        ("s/a^b/Y/", "a^b" & LF, "Y" & LF,
         "SUB-002 a caret away from the start is ordinary");
      Transforms
        ("s/a$b/Y/", "a$b" & LF, "Y" & LF,
         "SUB-002 a dollar away from the end is ordinary");
      Transforms
        ("s/ab*c/Y/", "abbc" & LF, "Y" & LF, "SUB-002 star quantifies");
      Transforms ("s/a.c/Y/", "abc" & LF, "Y" & LF, "SUB-002 dot matches one");
      Transforms
        ("s/[]a]/X/", "]" & LF, "X" & LF,
         "SUB-002 a leading bracket in a set is literal");
      Transforms
        ("s/[^a]/X/", "ab" & LF, "aX" & LF, "SUB-002 negated bracket set");
      Transforms
        ("N;s/\n/+/", "a" & LF & "b" & LF, "a+b" & LF,
         "SUB-002 the escape n matches an embedded newline");
   end Basic_Regular_Expression_Syntax;

   --  SUB-003: backreferences inside a pattern.
   --
   --  A backreference matches whatever the group captured, however long that
   --  was. A single-character group cannot distinguish that from matching one
   --  character, so every case below captures more than one.

   procedure Pattern_Backreferences
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("s/\(a\)\1/X/", "aa" & LF, "X" & LF,
         "SUB-003 single-character backreference");
      Transforms
        ("s/\(ab\)\1/X/", "abab" & LF, "X" & LF,
         "SUB-003 two-character backreference consumes the whole group");
      Transforms
        ("s/\(abc\)\1/X/", "abcabc" & LF, "X" & LF,
         "SUB-003 three-character backreference consumes the whole group");
      Transforms
        ("s/\(ab\)\1/X/", "abcabc" & LF, "abcabc" & LF,
         "SUB-003 a backreference that does not match leaves the line alone");
      Transforms
        ("s/\(.\)\1/D/g", "aabbcc" & LF, "DDD" & LF,
         "SUB-003 global substitution with a backreference");
      Transforms
        ("s/\(a\)\(b\)\2\1/M/", "abba" & LF, "M" & LF,
         "SUB-003 two groups referenced out of order");
      Transforms
        ("s/\(a*\)\1/[&]/", "aaaa" & LF, "[aaaa]" & LF,
         "SUB-003 backreference to a quantified group");

      --  "the line is some string written twice" is not a regular language,
      --  so this is the case a finite-automaton matcher cannot decide at all.
      Transforms
        ("s/^\(.*\)\1$/D/", "abab" & LF, "D" & LF,
         "SUB-003 a doubled line is recognized");
      Transforms
        ("s/^\(.*\)\1$/D/", "abac" & LF, "abac" & LF,
         "SUB-003 a line that is not doubled is left alone");
   end Pattern_Backreferences;

   --  INPUT-001: every operand forms one logical stream.

   procedure Logical_Input_Stream
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "one.txt", "a" & LF & "b" & LF);
      Doubles.Add_File (Files, "two.txt", "c" & LF);
      Doubles.Add_File (Files, "empty.txt", "");

      declare
         Numbering : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("="), A ("one.txt"), A ("two.txt")],
                Files);
         Final : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("$p"), A ("one.txt"), A ("two.txt")],
                Files);
         Trailing_Empty : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("$p"), A ("one.txt"), A ("empty.txt")],
                Files);
         Leading_Empty : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("="), A ("empty.txt"), A ("two.txt")],
                Files);
      begin
         Assert
           (Output (Numbering) = "1" & LF & "2" & LF & "3" & LF,
            "INPUT-001 line numbers continue across operands");
         Assert
           (Output (Final) = "c" & LF,
            "INPUT-001 the final address matches only the last line overall");
         Assert
           (Output (Trailing_Empty) = "b" & LF,
            "INPUT-001 a trailing empty operand does not move the final line");
         Assert
           (Output (Leading_Empty) = "1" & LF,
            "INPUT-001 an empty operand contributes no line");
      end;
   end Logical_Input_Stream;

   --  INPUT-002: standard input operands.

   procedure Standard_Input_Operands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "one.txt", "a" & LF);
      Doubles.Add_File (Files, "two.txt", "c" & LF);

      declare
         Between : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("p"),
                 A ("one.txt"), A ("-"), A ("two.txt")],
                Files,
                "b" & LF);
         Repeated : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("p"), A ("-"), A ("-")],
                Files,
                "s" & LF);
         Implicit : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("p")], "s" & LF);
      begin
         Assert
           (Output (Between) = "a" & LF & "b" & LF & "c" & LF,
            "INPUT-002 standard input takes its place among the operands");
         Assert
           (Output (Repeated) = "s" & LF,
            "INPUT-002 a repeated hyphen does not rewind standard input");
         Assert
           (Output (Implicit) = "s" & LF,
            "INPUT-002 with no operand standard input is read");
      end;
   end Standard_Input_Operands;

   --  INPUT-003: a final line with no newline is preserved byte for byte.

   procedure Unterminated_Final_Line
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
   begin
      Transforms
        ("p", "a", "a" & LF & "a", "INPUT-003 an unterminated line stays so");
      Transforms
        ("s/a/b/", "a", "b", "INPUT-003 substitution keeps the missing newline");
      Transforms
        ("s/a/b/", "a" & LF, "b" & LF,
         "INPUT-003 a terminated line keeps its newline");
   end Unterminated_Final_Line;

   --  FILE-001: r reads a file, and a missing file is treated as empty.

   procedure Read_Command
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "extra.txt", "X" & LF & "Y" & LF);

      declare
         Present : constant Run_Result :=
           Run ([A ("--"), A ("r extra.txt")], Files, "a" & LF);
         Missing : constant Run_Result :=
           Run ([A ("--"), A ("r absent.txt")], Files, "a" & LF);
      begin
         Assert
           (Output (Present) = "a" & LF & "X" & LF & "Y" & LF,
            "FILE-001 r appends the file after the cycle");
         Assert
           (Output (Missing) = "a" & LF,
            "FILE-001 a missing r file behaves as an empty file");
         Assert
           (Missing.Exit_Status = 0,
            "FILE-001 a missing r file is not an error condition");
         Assert
           (Errors (Missing) = "",
            "FILE-001 a missing r file produces no diagnostic");
      end;
   end Read_Command;

   --  FILE-002: w and s///w write to named files.

   procedure Write_Commands
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("/b/w kept.txt")],
                Files,
                "a" & LF & "b" & LF);
      begin
         Assert (Result.Exit_Status = 0, "FILE-002 w succeeds");
         Assert
           (Doubles.Content (Files, "kept.txt") = "b" & LF,
            "FILE-002 w writes the selected lines");
      end;

      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("--"), A ("s/a/A/w changed.txt")],
                Files,
                "a" & LF & "z" & LF);
      begin
         Assert (Result.Exit_Status = 0, "FILE-002 s///w succeeds");
         Assert
           (Doubles.Content (Files, "changed.txt") = "A" & LF,
            "FILE-002 s///w writes only lines that changed");
      end;
   end Write_Commands;

   --  OUTPUT-001: -n suppresses only the automatic print.

   procedure Quiet_Suppresses_Only_Automatic_Output
     (Test : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (Test);
      Files : Doubles.Memory_Filesystem;
   begin
      Doubles.Add_File (Files, "extra.txt", "R" & LF);

      declare
         Result : constant Run_Result :=
           Run ([A ("-n"), A ("--"),
                 A ("p" & LF & "=" & LF & "r extra.txt" & LF & "a\" & LF & "T")],
                Files,
                "a" & LF);
      begin
         --  Every explicit output command still produces output under -n, and
         --  the queued appends flush in the order the script named them.
         Assert
           (Output (Result) = "a" & LF & "1" & LF & "R" & LF & "T" & LF,
            "OUTPUT-001 explicit output survives -n, got ["
            & Output (Result) & "]");
      end;
   end Quiet_Suppresses_Only_Automatic_Output;

   overriding procedure Register_Tests (Test : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (Test, Printing_Commands'Access, "CMD-PRINT-001 p, P, = and l");
      Register_Routine
        (Test, Deletion_Commands'Access, "CMD-DELETE-001 d, D and q");
      Register_Routine
        (Test, Hold_Space_Commands'Access, "CMD-HOLD-001 h, H, g, G and x");
      Register_Routine
        (Test, Cycle_Commands'Access, "CMD-CYCLE-001 n and N");
      Register_Routine
        (Test, Text_Commands'Access, "CMD-TEXT-001 a, i and c");
      Register_Routine
        (Test, Branch_Commands'Access, "CMD-BRANCH-001 labels, b and t");
      Register_Routine
        (Test, Transliteration_Command'Access, "CMD-TRANSLIT-001 y");
      Register_Routine
        (Test, Grouping_And_Comments'Access,
         "CMD-GROUP-001 groups, negation and comments");
      Register_Routine
        (Test, Address_Forms'Access, "ADDR-001 address forms");
      Register_Routine
        (Test, Range_Reactivates'Access, "ADDR-002 range reactivation");
      Register_Routine
        (Test, Substitution_Behaviour'Access, "SUB-001 substitution");
      Register_Routine
        (Test, Basic_Regular_Expression_Syntax'Access,
         "SUB-002 basic regular expression syntax");
      Register_Routine
        (Test, Pattern_Backreferences'Access,
         "SUB-003 backreferences in a pattern");
      Register_Routine
        (Test, Logical_Input_Stream'Access, "INPUT-001 one logical stream");
      Register_Routine
        (Test, Standard_Input_Operands'Access,
         "INPUT-002 standard input operands");
      Register_Routine
        (Test, Unterminated_Final_Line'Access,
         "INPUT-003 unterminated final line");
      Register_Routine
        (Test, Read_Command'Access, "FILE-001 r command");
      Register_Routine
        (Test, Write_Commands'Access, "FILE-002 w and s///w");
      Register_Routine
        (Test, Quiet_Suppresses_Only_Automatic_Output'Access,
         "OUTPUT-001 -n suppresses only automatic output");
   end Register_Tests;

end Sed_Test_Suite.Conformance;

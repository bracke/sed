#  Reverse the order of lines, as tac does.
#
#  Each line is prepended to the hold space, and nothing is printed until
#  the last line, at which point the hold space holds the whole file
#  backwards. 1!G appends the accumulated text to the current line, h saves
#  the result, and $!d suppresses output on every line but the last.
1!G;h;$!d

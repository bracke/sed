#  Remove trailing spaces from every line.
#
#  Written as a space followed by "space star" so it matches one or more,
#  keeping the expression a POSIX basic regular expression: + is an
#  ordinary character in a BRE, not a repetition operator.
s/  *$//

#  Collapse runs of blank lines into a single blank line.
#
#  The range starts at a line with any character and ends at the next empty
#  one, so the first blank after text is inside the range and every further
#  blank is outside it. Negating the range deletes those.
/./,/^$/!d

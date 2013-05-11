BEGIN {
  output = 0;
  blanklines = 0;
}
{
  # Start output at NAME. 
  if ( $0 ~ /^NAME/ ) {
    output = 1;
  }
  # Blankline?
  if ( output && $0 ~ /^([ \t])*$/ ) {
    blanklines++;
    # Exit after second blankline.
    if ( blanklines > 1 ) { exit; }
    print;
  }
  # Char on line?
  if ( output && $0 ~ /[^ \t]/ ) {
    if ( blanklines > 0 ) { blanklines-- };
    print;
  }
}

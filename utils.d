/+
  Copyright (C) 2011,2012 Karsten Heinze <karsten@sidenotes.de>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.
+/

module utils;

import std.conv;
import std.math;
import std.string;
import std.traits;

import std.c.string;

import c.cdio.types;


/*
 * Use this function to convert strings
 * inside fixed size buffers!
 */
T bufferTo( T )( char[] buffer )
{
   char[] tmp;
   ulong length;
   
   length = strlen( cast( char* )buffer );
   tmp.length = length;

   // Do not copy trailing '\0' into tmp array!
   strncpy( cast( char* )tmp, cast( char* )buffer, length );
   return to!( T )( tmp );
}

T[] convert( T : T[], F )( F[] from )
{
  T[] to;
  T to_elem;

  foreach( F from_elem; from ) {
    to_elem = cast( T )from_elem; 
    if ( isIntegral!F ) {
      to ~= to_elem;
    } else {
      if ( to_elem !is null ) { to ~= to_elem; }
    }
  }

  return to;
}
unittest {
  int a = [ 0, 1, 2, 3 ];
  uint b = convert!( uint[] )( a );
  assert( a == b );
}

string pluralize( string s, long count = 0 ) {
  return ( abs( count ) == 1 ) ? s : s ~ "s";
}

string msfToString( msf_t v )
{
  return format( "[%02d:%02d.%02d]", v.m, v.s, v.f );

}

/+
  Copyright (C) 2011 Karsten Heinze <karsten.heinze@sidenotes.de>

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


module sources.utils;

import std.array;
import std.stdio;
import std.string;

import c.cdio.device;

import utils;

import sources.base;


// Some utils for handling sources.
Source[] generalize( S )( S[] sources )
{
  return convert!( Source[] )( sources );
}

void print( S )( S[] sources )
{
  writeln( sources.toString() );
}

string toString( S )( S[] sources )
{
  string[] lines;
  foreach( S source; sources ) {
    lines ~= format( "%10s %15s %s", source.type(), source.path(), cast( Driver )source.driver() );
    if ( source.isDevice() ) {
      Device d = cast( Device )source;
      Device.Info i = d.info();
      lines ~= format( "Vendor: %s, Model: %s, Revision: %s", i.vendor, i.model, i.revision );
    }
  }

  return lines.join( "\n" );
}

/+
  Copyright (C) 2013 Karsten Heinze <karsten@sidenotes.de>

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

module checkers.base;

import c.cdio.types;
import introspection;
import log;
import media;

interface Checker : introspection.Interface
{
    /**
     * Inits check of a track.
     *
     * Params:
     *   disc  = the disc
     *   track = the track of interrest
     * Returns:
     *   an id to use for subsequent calls regarding this check
     */
    ulong init( Disc disc, in ubyte track );

    /**
     * Feeds a check with data.
     *
     * Params:
     *   id     = the id of the check (see init())
     *   sector = the read sector
     *   data   = the read data (9 sectors, current in the middle)
     */
    void feed(
        in ulong id,
        in lsn_t sector,
        in ubyte[][ 9 ] data
        );

    /**
     * Finishs a check, returns <tt>true</tt> for success,
     * otherwise <tt>false</tt>. Writes the check result
     * as string to param <tt>result</tt>.
     *
     * Params:
     *   id = the id of the check (see init())
     * Returns:
     *   returns <tt>true</tt> for success, otherwise <tt>false</tt>,
     *   writes the check result as string to param <tt>result</tt>
     */
    bool finish( in ulong id, out string result );

    void connect( void delegate( string, LogLevel, string, bool, bool ) signalHandler );
    void disconnect( void delegate( string, LogLevel, string, bool, bool ) signalHandler );
    void emit( string emitter, LogLevel level, string message, bool lineBreak = true, bool prefix = true );
}

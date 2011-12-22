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

module readers.jobs;

import std.string;

import c.cdio.types;

import media;
import readers.base;




interface ReadFromDiscJob
{
  SectorRange sectorRange( Disc disc );
  bool fits( Disc disc );
  string description();
}

class ReadFromAudioDiscJob : ReadFromDiscJob
{
  Disc _disc;
  bool _wholeDisc;
  int _trackNumber;
  SectorRange _sectorRange;

  this() {
    _wholeDisc = true;
  }
    
  this( int trackNumber ) {
    _trackNumber = trackNumber;
  }

  this( lsn_t from, lsn_t to ) {
    _sectorRange = SectorRange( from, to );
  }

  bool fits( Disc disc ) {
    SectorRange sr = sectorRange( disc );
    return ( sr.from >= 0 && sr.to > 0 );
  }

  SectorRange sectorRange( Disc disc )
  {
    SectorRange failure = SectorRange();
    if ( disc is null ) return failure;

    if ( _wholeDisc ) {
      SectorRange tmp = SectorRange();
      foreach( track; disc.tracks() ) {
        if ( track.isAudio() ) {
          tmp.from = track.sectorRange().from;
          break;
        }
      }
      foreach( track; disc.tracks().reverse ) {
        if ( track.isAudio() ) {
          tmp.to = track.sectorRange().to;
          break;
        }
      }

      if ( tmp.valid() ) {
        return tmp;
      } else {
        return failure;
      }
    }

    if ( _trackNumber > 0 ) {
      try {
        Track track = disc.tracks[ _trackNumber - 1 ];
        if ( track.isAudio() ) {
          return track.sectorRange(); 
        } else {
          return failure;
        }
      } catch ( core.exception.RangeError e ) {
        return failure;
      }
    }

    if ( _sectorRange.from > -1 ) {
      Track f = disc.track( _sectorRange.from );
      Track t = disc.track( _sectorRange.to );

      bool c1 = ( f !is null && f.isAudio() );
      bool c2 = ( t !is null && t.isAudio() );

      if ( c1 && c2 ) {
        return _sectorRange;
      } else {
        return failure;
      }
    }

    // Should never come here.
    return failure;
  }

  string description()
  {
    if ( _wholeDisc ) {
      return "Read the whole disc.";
    } else if ( _trackNumber > 0 ) {
      return format( "Read track %d.", _trackNumber );
    } else {
      return format( "Read from sector %d to sector %d.", _sectorRange.from, _sectorRange.to );
    }
  }
}

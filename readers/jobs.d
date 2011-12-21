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

import std.math;

import c.cdio.types;

import media;
import readers.base;


interface ReadFromDiscJob
{
  lsn_t fromSector();
  lsn_t toSector();
  bool apply( Disc disc );
}

class ReadFromAudioDiscJob : ReadFromDiscJob
{
  Disc _disc;
  bool _wholeDisc;
  int _trackNumber;
  lsn_t _fromSector, _toSector;


  this() {
    _wholeDisc = true;
  }
    
  this( int trackNumber ) {
    _trackNumber = trackNumber;
  }

  this( lsn_t fromSector, lsn_t toSector ) {
    _fromSector = cast( int )fmin( fromSector, toSector );
    _toSector = cast( int )fmax( fromSector, toSector );
  }

  bool apply( Disc disc ) {
    if ( fromSector() >= 0 && toSector() > 0 ) {
      _disc = disc;
      return true;
    }

    return false;
  }

  lsn_t fromSector()
  {
    if ( _disc is null ) return -1;

    if ( _wholeDisc ) {
      foreach( track; _disc.tracks() ) {
        if ( track.isAudio() ) {
          return track.firstSector();
        }
      }
      // No audio track.
      return -1;
    }

    if ( _trackNumber > 0 ) {
      try {
        Track track = _disc.tracks[ _trackNumber ];
        if ( track.isAudio() ) {
          return track.firstSector(); 
        } else {
          return -1;
        }
      } catch ( Exception e ) {
        return -1;
      }
    }

    if ( _fromSector > 0 ) {
      Track track = _disc.track( _fromSector );
      if ( track !is null && track.isAudio() ) {
        return _fromSector;
      } else {
        return -1;
      }
    }

    return -1;
  }

  lsn_t toSector()
  {
    if ( _disc is null ) return -1;

    if ( _wholeDisc ) {
      foreach( track; _disc.tracks().reverse ) {
        if ( track.isAudio() ) {
          return track.lastSector();
        }
      }
      // No audio track.
      return -1;
    }

    if ( _trackNumber > 0 ) {
      try {
        Track track = _disc.tracks[ _trackNumber ];
        if ( track.isAudio() ) {
          return track.lastSector(); 
        } else {
          return -1;
        }
      } catch ( Exception e ) {
        return -1;
      }
    }

    if ( _toSector > 0 ) {
      Track track = _disc.track( _toSector );
      if ( track !is null && track.isAudio() ) {
        return _toSector;
      } else {
        return -1;
      }
    }

    return -1;
  }
}

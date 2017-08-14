/+
  Copyright (C) 2011-2013 Karsten Heinze <karsten@sidenotes.de>

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

import core.exception;

import std.conv;
import std.file;
import std.stdio;
import std.string;

import c.cdio.types;

import media;
import parsers;
import readers.base;
import utils;
import writers.base;


enum Label
{
  NONE,
  DISC_BEGIN,
  DISC_END,
  TRACK_BEGIN,
  TRACK_END
}

interface ReadFromDiscJob
{
  SectorRange sectorRange( Disc disc );
  bool fits( Disc disc );
  string description( Disc disc = null );
  ReadFromDiscJob[] split( Disc disc );
  bool disc();
  ubyte track();
}

class ReadFromAudioDiscJob : ReadFromDiscJob
{
  bool _wholeDisc;
  ubyte _track, _fromTrack, _toTrack;
  lsn_t _fromSector, _toSector;
  Label _fromLabel, _toLabel;
  SectorRange _sectorRange;

  this() {
    _wholeDisc = true;
  }
    
  this( ubyte track ) {
    _track = track;
  }

  this( Label label, ubyte track, lsn_t sector )
  {
    if ( label == Label.DISC_BEGIN || label == Label.TRACK_BEGIN ) {
      _fromLabel = label;
      _toTrack = track;
      _toSector = sector;
    } else if ( label == Label.DISC_END || label == Label.TRACK_END ) {
      _fromTrack = track;
      _fromSector = sector;
      _toLabel = label;
    } else {
      throw new Exception( format( "Label %s is not supported", to!string( label ) ) );
    }
  }

  this( ubyte fromTrack, lsn_t fromSector, ubyte toTrack, lsn_t toSector )
  {
    _fromTrack = fromTrack;
    _fromSector = fromSector;
    _toTrack = toTrack;
    _toSector = toSector;
  }

  this( lsn_t from, lsn_t to ) {
    _sectorRange = SectorRange( from, to );
  }

  bool fits( Disc disc ) {
    return sectorRange( disc ).valid();
  }

  bool disc()
  {
    return _wholeDisc;
  }

  ubyte track()
  {
    return _track;
  }

  SectorRange sectorRange( Disc disc )
  {
    SectorRange failure = SectorRange();
    if ( disc is null ) return failure;


    Track[] tracks = disc.tracks();

    if ( _wholeDisc ) {
      SectorRange tmp = SectorRange();
      foreach( track; tracks ) {
        if ( track.isAudio() ) {
          tmp.from = track.sectorRange().from;
          break;
        }
      }
      foreach_reverse ( track; tracks ) {
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

    if ( _track > 0 ) {
      try {
        Track track = tracks[ _track - 1 ];
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
      if ( ! _sectorRange.valid() ) { return failure; }

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

    if ( _fromTrack > 0 && _toTrack > 0 ) {
      try {
        // Is audio track?
        if ( ! tracks[ _fromTrack - 1 ].isAudio() ) { return failure; }
        // Is audio track?
        if ( ! tracks[ _toTrack - 1 ].isAudio() ) { return failure; }

        SectorRange sr = SectorRange();
        sr.from = tracks[ _fromTrack - 1 ].sectorRange().from + _fromSector;
        sr.to = tracks[ _toTrack - 1 ].sectorRange().from;
        // Offset?
        if ( _toSector >= 0 ) {
          sr.to += _toSector;
        } else {
          sr.to = tracks[ _toTrack - 1 ].sectorRange().to;
        }

        if ( sr.valid() ) {
          // OK, lets check if sectors belong to right tracks.
          if ( disc.track( sr.from ).number() != _fromTrack ) {
            return failure;
          }
          if ( disc.track( sr.to ).number() != _toTrack ) {
            return failure;
          }

          // Everything is fine.
          return sr;
        } else {
          return failure;
        }
      } catch ( core.exception.RangeError e ) {
        return failure;
      }
    }

    if ( _fromTrack > 0 ) {
      try {
        // Is audio track?
        if ( ! tracks[ _fromTrack - 1 ].isAudio() ) { return failure; }

        // Build sector range.
        SectorRange sr = SectorRange();
        sr.from = tracks[ _fromTrack - 1 ].sectorRange().from + _fromSector;
        // OK, lets check if sector belongs to right track.
        if ( disc.track( sr.from ).number() != _fromTrack ) {
          return failure;
        }

        // Only label END makes sense here.
        if ( _toLabel == Label.DISC_END ) {
          // Find last audio track.
          foreach_reverse ( track; tracks ) {
            if ( track.isAudio() ) {
              sr.to = track.sectorRange().to;
              if ( sr.valid() ) {
                return sr;
              } else {
                break;
              }
            }
          }
        }
        if (  _toLabel == Label.TRACK_END ) {
          sr.to = tracks[ _fromTrack - 1 ].sectorRange().to;
          return sr;
        }

        return failure;
      } catch ( core.exception.RangeError e ) {
        return failure;
      }
    }

    if ( _toTrack > 0 ) {
      try {
        // Is audio track?
        if ( ! tracks[ _toTrack - 1 ].isAudio() ) { return failure; }

        // Build sector range.
        SectorRange sr = SectorRange();
        sr.to = tracks[ _toTrack - 1 ].sectorRange().from; 
        // Offset?
        if ( _toSector >= 0 ) {
          sr.to += _toSector;
        } else {
          sr.to = tracks[ _toTrack - 1 ].sectorRange().to;  
        }
        // OK, lets check if sector belongs to right track.
        if ( disc.track( sr.to ).number() != _toTrack ) {
          return failure;
        }

        // Only label BEGIN makes sense here.
        if ( _fromLabel == Label.DISC_BEGIN ) {
          // Find last audio track.
          foreach ( track; tracks ) {
            if ( track.isAudio() ) {
              sr.from = track.sectorRange().from;
              if ( sr.valid() ) {
                return sr;
              } else {
                break;
              }
            }
          }
        }
        if ( _fromLabel == Label.TRACK_BEGIN ) {
          sr.from = tracks[ _toTrack - 1 ].sectorRange().from; 
          return sr;
        }

        return failure;
      } catch ( core.exception.RangeError e ) {
        return failure;
      }
    }

    // Nothing matched.
    return failure;
  }

  ReadFromDiscJob[] split( Disc disc )
  {
    // Return self if disc doesn't fit job.
    if ( ! this.fits( disc ) ) {
      return [ this ];
    }


    // Check if multiple tracks are covered by job.
    SectorRange sr = sectorRange( disc );

    Track t1 = disc.track( sr.from );
    Track t2 = disc.track( sr.to );

    // One track.
    if ( t1 == t2 ) {
      return [ this ];
    }

    // Multiple tracks.
    ReadFromDiscJob[] jobs;

    // Add first job.
    if ( sr.from == t1.firstSector() ) {
      jobs ~= new ReadFromAudioDiscJob( t1.number() );
    } else {
      jobs ~= new ReadFromAudioDiscJob( sr.from, t1.lastSector() );
    }

    // Add jobs between first and last job.
    foreach( Track t; disc.tracks()[ t1.number() .. t2.number() - 1 ] ) {
      jobs ~= new ReadFromAudioDiscJob( t.number() );
    }

    // Add last job.
    if ( t2.lastSector() == sr.to ) {
      jobs ~= new ReadFromAudioDiscJob( t2.number() );
    } else {
      jobs ~= new ReadFromAudioDiscJob( t2.firstSector(), sr.to );
    }

    return jobs;
  }

  string description( Disc disc = null )
  {
    if ( _wholeDisc ) {
      return "Read the whole disc.";
    } else if ( _track > 0 ) {
      return format( "Read track %d.", _track );
    } else if ( _sectorRange.valid() )  {
      return format( "Read from sector %d to sector %d.", _sectorRange.from, _sectorRange.to );
    } else if ( _fromTrack > 0 && _toTrack > 0 ) {
      if ( _toSector < 0 ) {
        return format(
            "Read from track %d (sector: %d) to end of track %d.",
            _fromTrack,
            _fromSector,
            _toTrack
          );
      }
      return format(
          "Read from track %d (sector: %d) to track %d (sector: %d).",
          _fromTrack,
          _fromSector,
          _toTrack,
          _toSector
        );
    } else if ( _fromTrack > 0 ) {
      return format(
           "Read from track %d (sector: %d) to end of disc.",
          _fromTrack,
          _fromSector
        );
    } else if ( _toTrack > 0 ) {
      if ( _toSector < 0 ) {
        return format(
            "Read from begin of disc to end of track %d.",
            _toTrack
          );
      }
      return format(
          "Read from begin of disc to track %d (sector: %d).",
          _toTrack,
          _toSector
        );
    }

    // Should never get here.
    return "Read something.";
  }
}

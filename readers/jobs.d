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

import std.conv;
import std.file;
import std.stdio;
import std.stream;
import std.string;

import c.cdio.types;

import media;
import parsers;
import readers.base;
import utils;
import writers.base;


enum Labels
{
  NONE,
  DISC_BEGIN,
  DISC_END,
  TRACK_BEGIN,
  TRACK_END
}

struct Target
{
  // Type of writer to use. 
  string writerClass;
  // Where to write data to.
  string file;
  // How to open file.
  FileMode mode;

  Writer build()
  {
    Writer w = cast( Writer )Object.factory( writerClass );
    // Check that writer object was created.
    if ( w is null ) { return null; };

    w.setPath( file );
    w.setMode( mode );
    return w;
  }
}

interface ReadFromDiscJob
{
  SectorRange sectorRange( Disc disc );
  bool fits( Disc disc );
  @property ref Target target();
  @property void target( Target target );
  string description();
  ReadFromDiscJob[] trackwise( Disc disc, FilenameGenerator generator );
}

class ReadFromAudioDiscJob : ReadFromDiscJob
{
  Disc _disc;
  bool _wholeDisc;
  int _track, _fromTrack, _toTrack;
  lsn_t _fromSector, _toSector;
  Labels _fromLabel, _toLabel;
  SectorRange _sectorRange;
  Target _target = Target( "writers.wav.FileWriter", "out.wav", FileMode.OutNew | FileMode.In );

  this() {
    _wholeDisc = true;
  }
    
  this( int track ) {
    _track = track;
  }

  this( Labels label, int track, lsn_t sector )
  {
    if ( label == Labels.DISC_BEGIN || label == Labels.TRACK_BEGIN ) {
      _fromLabel = label;
      _toTrack = track;
      _toSector = sector;
    } else if ( label == Labels.DISC_END || label == Labels.TRACK_END ) {
      _fromTrack = track;
      _fromSector = sector;
      _toLabel = label;
    } else {
      throw new Exception( format( "Label %s is not supported", to!string( label ) ) );
    }
  }

  this( int fromTrack, lsn_t fromSector, int toTrack, lsn_t toSector )
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
      foreach( track; tracks.dup.reverse ) {
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
        if ( _toLabel == Labels.DISC_END ) {
          // Find last audio track.
          foreach ( track; tracks.dup.reverse ) {
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
        if (  _toLabel == Labels.TRACK_END ) {
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
        if ( _fromLabel == Labels.DISC_BEGIN ) {
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
        if ( _fromLabel == Labels.TRACK_BEGIN ) {
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

  @property ref Target target()
  {
    return _target;
  }

  @property void target( Target target ) {
    _target = target; 
  }

  ReadFromDiscJob[] trackwise( Disc disc, FilenameGenerator generator )
  {
    if ( generator is null ) {
      throw new Exception( "No filename generator passed" );
    }

    ReadFromDiscJob[] jobs;

    // If target is stdout then splitting makes no sense!
    if ( this.target.file == generator.generate( stdout ) ) { return [ this ]; }


    // Check if multiple tracks are covered by job.
    SectorRange sr = sectorRange( disc );
    Track t1 = disc.track( sr.from );
    Track t2 = disc.track( sr.to );

    // One track.
    if ( t1 == t2 ) {
      this.target.file = generator.generate( sr.from, sr.to );
      jobs ~= this;
      return jobs;
    }

    // FIXME: Use original file extension!!!
    // Multiple tracks.
    ReadFromAudioDiscJob j;

    // Add first job.
    if ( sr.from == t1.firstSector() ) {
      j = new ReadFromAudioDiscJob( t1.number() );
      j.target = this.target;
      j.target.file = generator.generate( t1.number() );
    } else {
      j = new ReadFromAudioDiscJob( sr.from, t1.lastSector() );
      j.target = this.target;
      j.target.file = generator.generate( 
          Labels.TRACK_END,
          t1.number(),
          SectorRange( t1.firstSector(), sr.from ).length() - 1
        );
    }
    jobs ~= j;

    // Add jobs between first and last job.
    foreach( Track t; disc.tracks()[ t1.number() .. t2.number() - 1 ] ) {
      j = new ReadFromAudioDiscJob( t.number() );
      j.target = this.target;
      j.target.file = generator.generate( t.number() );

      jobs ~= j;
    }

    // Add last job.
    if ( t2.lastSector() == sr.to ) {
      j = new ReadFromAudioDiscJob( t2.number() );
      j.target = this.target;
      j.target.file = generator.generate( t2.number );
    } else {
      j = new ReadFromAudioDiscJob( t2.firstSector(), sr.to );
      j.target = this.target;
      j.target.file = generator.generate( 
          Labels.TRACK_BEGIN,
          t2.number(),
          SectorRange( t2.firstSector(), sr.to ).length() - 1
        );

    }
    jobs ~= j;
       

    return jobs;
  }

  string description()
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

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

module media;

import std.algorithm;
import std.conv;
import std.math;
import std.string;

import c.cdio.sector;
import c.cdio.types;


struct SectorRange
{
  lsn_t from = -1;
  lsn_t to = -1;

  this( lsn_t f, lsn_t t )
  {
    from = cast( lsn_t )fmin( f, t );
    to = cast( lsn_t )fmax( f, t );
  }

  bool valid()
  {
    return ( from >= 0 && to >= 0 && from <= to );
  }

  uint sectors()
  {
    return ( to - from + 1 );
  }

  uint length()
  {
    return sectors();
  }
}


class Disc
{
private:
  string _mcn;
  Track[] _tracks;
  bool _sorted;

public:
  this() {};

  Track[] tracks() {
    if ( !_sorted ) {
      sort!( function bool( Track a, Track b ) { return ( a.number < b.number ); } )( _tracks );
      _sorted = true;
    }

    return _tracks;
  }

  void addTrack( Track track ) {
    _tracks ~= track;
    _sorted = false;
  }

  void setMcn( string mcn ) {
    _mcn = mcn;
  }

  string mcn() {
    return _mcn;
  }

  bool isAudio() {
    foreach( track; _tracks ) {
      if ( track.isAudio() ) return true;
    }

    return false;
  }

  lsn_t sectors()
  {
    uint sum;
    foreach( track; tracks() ) {
      sum += track.sectors();
    }

    return sum;
  }

  uint seconds()
  {
    return sectors() / CDIO_CD_FRAMES_PER_SEC;
  }

  string length()
  {
    uint m = seconds() / CDIO_CD_SECS_PER_MIN;
    uint s = seconds() % CDIO_CD_SECS_PER_MIN;

    return format( "%d:%02d", m, s );
  }

  Track track( lsn_t sector )
  {
    foreach( track; _tracks ) {
      SectorRange range = track.sectorRange();
      if ( sector >= range.from && sector <= range.to ) {
        return track;
      }
    }

    return null;
  }
}

class Track
{
private:
  ubyte _number;
  SectorRange _sectorRange;
  bool _audio;

public:
  this( ubyte number, lsn_t firstSector, lsn_t lastSector, bool audio )
  {
    _number = number;
    _sectorRange = SectorRange( firstSector, lastSector );
    _audio = audio;
  }

  this( ubyte number, msf_t begin, msf_t end, bool audio )
  {
    _number = number;
    lsn_t firstSector = msfToSectors( begin );
    lsn_t lastSector = msfToSectors( end );
    _sectorRange = SectorRange( firstSector, lastSector );
    _audio = audio;
  }

  ubyte number()
  {
    return _number;
  }

  bool isAudio()
  {
    return _audio;
  }

  SectorRange sectorRange()
  {
    return _sectorRange;
  }

  lsn_t sectors()
  {
    return _sectorRange.sectors();
  }

  lsn_t firstSector()
  {
    return _sectorRange.from;
  }

  lsn_t lastSector()
  {
    return _sectorRange.to;
  }

  uint seconds()
  {
    return sectors() / CDIO_CD_FRAMES_PER_SEC;
  }

  string length()
  {
    uint m = seconds() / CDIO_CD_SECS_PER_MIN;
    uint s = seconds() % CDIO_CD_SECS_PER_MIN;

    return format( "%d:%02d", m, s );
  }
}

msf_t sectorsToMsf( lsn_t sectors ) {
  msf_t result;

  result.m = cast( ubyte )( sectors / ( CDIO_CD_FRAMES_PER_SEC * CDIO_CD_SECS_PER_MIN ) );
  result.s = cast( ubyte )( ( sectors % ( CDIO_CD_FRAMES_PER_SEC * CDIO_CD_SECS_PER_MIN ) ) / CDIO_CD_FRAMES_PER_SEC );
  result.f = cast( ubyte )( ( sectors % ( CDIO_CD_FRAMES_PER_SEC * CDIO_CD_SECS_PER_MIN ) ) % CDIO_CD_FRAMES_PER_SEC );

  return result;
}
unittest { 
  lsn_t from = ( 61 * 75 ) + 1;
  msf_t to = sectorsToMsf( from );
  assert( to.m == 1 );
  assert( to.s == 1 );
  assert( to.f == 1 );
}

lsn_t msfToSectors( msf_t from ) {
  lsn_t result;

  result += ( from.m * 60 * CDIO_CD_FRAMES_PER_SEC );
  result += ( from.s * CDIO_CD_FRAMES_PER_SEC );
  result += from.f;
  return result;
}
unittest {
  msf_t from = msf_t( 1, 1, 1 );
  lsn_t to = msfToSectors( from );

  assert( to == 4576 );
}

string discToString( Disc disc ) {
  string[] lines;

  lines ~= format( "%6s: %s", "MCN", disc.mcn().length ? disc.mcn() : "none" );
  lines ~= format( "%6s: %s", "Tracks", disc.tracks().length );
  if ( disc.isAudio() ) {
    lines ~= format( "%6s: %s", "Length", disc.length() );
    lines ~= "";
    lines ~= format( "%2s   %-6s   %-15s   %s", "#", "Length", "Sectors", "Type" );
    foreach( Track track; disc.tracks() ) {
      lines ~= format( "%2d   %6s   %6d : %6d   %3.1s", track.number(), track.length(), track.firstSector(), track.lastSector(), ( track.isAudio() ? "A" : "D" ) );
    }
  } else {
    lines ~= "";
    lines ~= format( "%2s   %-15s   %s", "#", "Sectors", "Type" );
    foreach( Track track; disc.tracks() ) {
      lines ~= format( "%2d   %6d : %6d   %3.1s", track.number(), track.firstSector(), track.lastSector(), ( track.isAudio() ? "A" : "D" ) );
    }
  }

  return lines.join( "\n" );
}

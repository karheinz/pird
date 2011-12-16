module media;

import std.algorithm;
import std.conv;
import std.string;

import c.cdio.sector;
import c.cdio.types;


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
}
alias Disc Mask;

class Track
{
private:
  ubyte _number;
  lsn_t _firstSector, _lastSector;
  bool _audio;

public:
  this( ubyte number, lsn_t firstSector, lsn_t lastSector, bool audio )
  {
    _number = number;
    _firstSector = firstSector;
    _lastSector = lastSector;
    _audio = audio;
  }

  this( ubyte number, msf_t begin, msf_t end, bool audio )
  {
    _firstSector = cdio_msf_to_lsn( &begin );
    _lastSector = cdio_msf_to_lsn( &end );
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

  lsn_t firstSector()
  {
    return _firstSector;
  }

  lsn_t lastSector()
  {
    return _lastSector;
  }

  lsn_t sectors()
  {
    return ( _lastSector - _firstSector + 1 );
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

string discToString( Disc disc ) {
  string[] lines;

  lines ~= format( "%6s: %s", "MCN", disc.mcn().length ? disc.mcn() : "none" );
  lines ~= format( "%6s: %s", "Tracks", disc.tracks().length );
  if ( disc.isAudio() ) {
    lines ~= format( "%6s: %s", "Length", disc.length() );
    lines ~= "";
    lines ~= format( "%2s   %-6s   %-13s   %s", "#", "Length", "Sectors", "Type" );
    foreach( Track track; disc.tracks() ) {
      lines ~= format( "%2d   %6s   %5d : %5d   %3.1s", track.number(), track.length(), track.firstSector(), track.lastSector(), ( track.isAudio() ? "A" : "D" ) );
    }
  } else {
    lines ~= "";
    lines ~= format( "%2s   %-13s   %s", "#", "Sectors", "Type" );
    foreach( Track track; disc.tracks() ) {
      lines ~= format( "%2d   %5d : %5d   %3.1s", track.number(), track.firstSector(), track.lastSector(), ( track.isAudio() ? "A" : "D" ) );
    }
  }

  return lines.join( "\n" );
}

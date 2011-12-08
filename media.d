module media;

import std.algorithm;

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
}

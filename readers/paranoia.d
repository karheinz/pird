module readers.paranoia;

import std.math;
import std.signals;
import std.stdio;
import std.string;

import c.cdio.cdda;
import c.cdio.disc;
import c.cdio.track;
import c.cdio.types;

import introspection;
import log;
import media;
import readers.base;
import sources.base;


class ParanoiaReader : Reader
{
private:
  Source _source;
  cdrom_drive_t* _handle;
public:
  this() {};
  this( Source source )
  {
    _source = source;
  }

  void setSource( Source source ) {
    _source = source;
  }

  Disc disc()
  {
    // Abort if source is no device.
    if ( ! _source.isDevice() ) {
      logError( format( "%s is no device!", _source.path() ) );
      return null;
    }

    // Open source.
    if ( !_source.open() ) {
      logError( format( "Failed to open %s!", _source.path() ) ); 
      return null;
    }

    // Paranoia reader only supports audio discs.
    discmode_t discmode = cdio_get_discmode( _source.handle() );
    if ( discmode != discmode_t.CDIO_DISC_MODE_CD_DA &&
        discmode != discmode_t.CDIO_DISC_MODE_CD_MIXED ) {
      logError( format( "Discmode %s is not supported!", discmode2str[ discmode ] ) );
      return null;
    }

    // Build disc.
    char** dummy;
    _handle = cdio_cddap_identify_cdio( _source.handle(), 0, dummy );
    if ( _handle is null ) {
      logError( "No cdrom_drive_t handle available!" );
      return null;
    }

    Disc disc = new Disc();
    track_t tracks = cdio_cddap_tracks( _handle );
    for( track_t track = 1; track <= tracks; track++ ) {
      lsn_t fs = cdio_cddap_track_firstsector( _handle, track );
      lsn_t ls = cdio_cddap_track_lastsector( _handle, track );
      disc.addTrack( new Track( track, fs, ls, true ) );
      logDebug( format( "Added track %d (%d - %d).", track, fs, ls ) ); 

      // In case tracks is 255.
      if ( track == track_t.max ) break;
    }

    return disc;
  }

  long read( Mask mask = null ) {
    return 0;
  }

  mixin introspection.Implementation;
  mixin Log;
}

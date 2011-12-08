module readers.audio;

import std.array;
import std.conv;
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


class AudioReader : Reader
{
private:
  Source _source;
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
    // Open source.
    if ( !_source.open() ) {
      logError( format( "Failed to open %s!", _source.path() ) ); 
      return null;
    }

    // Default reader only supports audio discs.
    discmode_t discmode = cdio_get_discmode( _source.handle() );
    if ( discmode != discmode_t.CDIO_DISC_MODE_CD_DA &&
        discmode != discmode_t.CDIO_DISC_MODE_CD_MIXED ) {
      logError( format( "Discmode %s is not supported!", discmode ) );
      return null;
    }

    logTrace( "Exploring audio disc." );

    // Build disc.
    Disc disc = new Disc();

    // Retrieve media catalog number and apply to disc.
    char* mcn = cdio_get_mcn( _source.handle() );
    disc.setMcn( to!string( mcn ) );
    delete mcn;

    // Retrieve tracks and add them to disc.
    track_t tracks = cdio_get_num_tracks( _source.handle() );
    track_format_t trackFormat;
    lsn_t firstSector, lastSector;
    for( track_t track = 1; track <= tracks; track++ ) {
      trackFormat = cdio_get_track_format( _source.handle(), track );
      firstSector = cdio_get_track_lsn( _source.handle(), track );
      lastSector = cdio_get_track_last_lsn( _source.handle(), track );
      if ( trackFormat == track_format_t.TRACK_FORMAT_AUDIO ) {
        logTrace( format( "Found audio track %d (%d - %d).", track, firstSector, lastSector ) ); 
      } else {
        logTrace( format( "Found non audio track %d (%d - %d).", track, firstSector, lastSector ) ); 
      }

      disc.addTrack(
        new Track( 
          track,
          firstSector,
          lastSector,
          trackFormat == track_format_t.TRACK_FORMAT_AUDIO
        )
      );

      // In case tracks is 255.
      if ( track == track_t.max ) break;
    }

    // Log what we found.
    if ( disc.mcn().empty() ) {
      logDebug(
        format(
          "Found disc with %d tracks and without media catalog number.",
          tracks
        )
      );
    } else {
      logDebug(
        format(
          "Found disc with %d tracks and with media catalog number %s.",
          tracks,
          disc.mcn()
        )
      );
    }

    return disc;
  }

  long read( Mask mask = null ) {
    Disc disc = disc();

    // No disc?
    if ( disc is null ) { return 0; }

    // Read each track. 
    // TODO: Mask!
    foreach( track; disc.tracks() ) {
      logDebug( format( "Read track %d.", track.number() ) );
    }

    return 0;
  }

  mixin introspection.Implementation;
  mixin Log;
}

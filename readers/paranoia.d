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
import readers.jobs;
import sources.base;


class ParanoiaAudioDiscReader : AudioDiscReader
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
      throw new Exception( format( "%s is no device", _source.path() ) );
    }

    // Open source.
    if ( ! _source.open() ) {
      throw new Exception( format( "Failed to open %s", _source.path() ) ); 
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
      throw new Exception( "No cdrom_drive_t handle available" );
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

  bool add( ReadFromDiscJob job ) {
    return job.apply( disc() );
  }


  mixin introspection.Initial;
  mixin Log;
}

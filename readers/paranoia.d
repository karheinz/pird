/+
  Copyright (C) 2011,2012 Karsten Heinze <karsten@sidenotes.de>

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

import std.array;
import std.conv;
import std.math;
import std.signals;
import std.stdio;
import std.string;

import c.cdio.cdda;
import c.cdio.device;
import c.cdio.disc;
import c.cdio.track;
import c.cdio.types;

import introspection;
import log;
import media;
import readers.base;
import readers.jobs;
import sources.base;


class ParanoiaAudioDiscReader : AbstractAudioDiscReader
{
private:
  cdrom_drive_t* _handle;

public:
  this() {};
  this( Source source )
  {
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

    // Media changed since last call?
    if ( ! cdio_get_media_changed( _source.handle() ) ) {
      // Maybe we already explored the disc.
      if ( _disc !is null ) return _disc;
    }

    // Either media is unknown or media changed.

    // Paranoia reader only supports audio discs.
    discmode_t discmode = cdio_get_discmode( _source.handle() );
    if ( discmode != discmode_t.CDIO_DISC_MODE_CD_DA &&
        discmode != discmode_t.CDIO_DISC_MODE_CD_MIXED ) {
      logDebug( format( "Discmode %s is not supported!", to!string( discmode ) ) );
      logDebug( "No audio disc found!" );
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
    track_format_t trackFormat;
    lsn_t firstSector, lastSector;
    for ( track_t track = 1; track <= tracks; track++ ) {
      trackFormat = cdio_get_track_format( _source.handle(), track );
      firstSector= cdio_cddap_track_firstsector( _handle, track );
      lastSector= cdio_cddap_track_lastsector( _handle, track );
      if ( trackFormat == track_format_t.TRACK_FORMAT_AUDIO ) {
        logTrace( format( "Found audio track %d (%d - %d).", track, firstSector, lastSector) ); 
      } else {
        logTrace( format( "Found non audio track %d (%d - %d).", track, firstSector, lastSector) ); 
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
    string word = ( disc.mcn().length ? format( " %s", disc.mcn() ) : "" );
    logDebug( format( "Found audio disc%s with %d tracks.", word, tracks ) );

    // Cache result.
    _disc = disc;

    return _disc;
  }

  bool read()
  {
    if ( _jobs.length == 0 ) {
      logInfo( "Nothing to do." );
      return true;
    }

    ReadFromDiscJob job;
    while ( _jobs.length ) {
      job = _jobs.front();
      _jobs.popFront();

      logInfo( "Start job: " ~ job.description() );
    }

    return true;
  }


  mixin introspection.Override;
  mixin Log;
}

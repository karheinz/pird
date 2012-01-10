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

module readers.simple;

import std.array;
import std.conv;
import std.math;
import std.signals;
import std.stdio;
import std.string;

import c.cdio.cdda;
import c.cdio.device;
import c.cdio.disc;
import c.cdio.read;
import c.cdio.sector;
import c.cdio.track;
import c.cdio.types;

import introspection;
import log;
import media;
import parsers;
import readers.base;
import readers.jobs;
import sources.base;
import utils;
import writers.base;


class SimpleAudioDiscReader : AbstractAudioDiscReader
{
public:
  this() {};
  this( Source source )
  {
    _source = source;
  }

  Disc disc()
  {
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

    // Default reader only supports audio discs.
    discmode_t discmode = cdio_get_discmode( _source.handle() );
    if ( discmode != discmode_t.CDIO_DISC_MODE_CD_DA &&
        discmode != discmode_t.CDIO_DISC_MODE_CD_MIXED ) {
      logTrace( format( "Discmode %s is not supported!", discmode2str[ discmode ] ) );
      logDebug( "No audio disc found!" );
      return null;
    }

    logTrace( "Found audio disc." );

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
    for ( track_t track = 1; track <= tracks; track++ ) {
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
    string word = ( disc.mcn().length ? format( " %s", disc.mcn() ) : "" );
    logDebug( format( "Found audio disc%s with %d tracks.", word, tracks ) );

    // Cache result.
    _disc = disc;

    return _disc;
  }

  bool read()
  {
    // Something to do?
    if ( _jobs.length == 0 ) {
      logInfo( "Nothing to do." );
      return true;
    }

    ReadFromDiscJob job;
    while ( _jobs.length ) {
      job = _jobs.front();
      _jobs.popFront();

      // Check if job fits disc.
      if ( ! job.fits( disc() ) ) {
        logWarning( "Job is unapplicable to disc: " ~ job.description() );
        logWarning( "Skip job: " ~ job.description() );
        continue;
      }

      // Check if writer is available.
      logTrace( "Writer class is " ~ _target.writerClass );
      Writer writer = _target.build( job, disc() );

      if ( writer is null ) {
        logWarning( "Failed to create writer instance!" );
        return false;
      }

      // Heyho, lets go!
      logInfo( "Start job: " ~ job.description() );

      // Init some vars.
      driver_return_code_t rc;
      ubyte[ CDIO_CD_FRAMESIZE_RAW ] buffer;
      SectorRange sr = job.sectorRange( disc() );

      // Tell writer how much bytes (expected) to be written.
      writer.setExpectedSize( sr.length * CDIO_CD_FRAMESIZE_RAW );

      // Open writer.
      writer.open();
      
      // Rip!
      logInfo(
          format(
            "Try to read %d %s starting at sector %d.",
            sr.length(),
            "sector".pluralize( sr.length() ),
            sr.from
          )
        );
      logInfo( "Data is written to " ~ writer.path() ~ "." );

      for ( lsn_t sector = sr.from; sector <= sr.to; sector++ ) {
        rc = cdio_read_audio_sector( _source.handle(), buffer.ptr, sector );        
        if ( rc == driver_return_code.DRIVER_OP_SUCCESS ) {
          writer.write( buffer );
          continue;
        }

        logError( format( "Reading sector %d failed: %s, abort!", sector, to!string( rc ) ) );
        // Set sr.to to last successfully read sector.
        sr.to = cast( lsn_t )( sector - 1 );
        break;
      }

      // Close writer.
      writer.close();
      logInfo( format( "Read and wrote %d %s.", sr.length(), "sector".pluralize( sr.length() ) ) );
    }

    return true;
  }


  mixin introspection.Override;
  mixin Log;
}

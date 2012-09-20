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
import c.cdio.paranoia;
import c.cdio.sector;
import c.cdio.track;
import c.cdio.types;

import introspection;
import log;
import media;
import readers.base;
import readers.jobs;
import readers.mixins;
import sources.base;
import utils;
import writers.base;


class ParanoiaAudioDiscReader : AbstractAudioDiscReader
{
public:
  override void setSource( GenericSource source )
  {
    // We need access to a cdrom_paranoia_t pointer! Cast is required.
    if ( cast( Source!cdrom_paranoia_t )( source ) is null ) {
      throw new Exception( format( "%s is no %", source.path(), typeid( Source!cdrom_paranoia_t ) ) ); 
    }
    _source = source;
    _disc = null;
  }

  this() {};
  this( GenericSource source )
  {
    setSource( source );
  }

  bool read()
  {
    // Abort if source is no device.
    if ( ! _source.isDevice() ) {
      throw new Exception( format( "%s is no device", _source.path() ) );
    }

    // Handle.
    cdrom_paranoia_t* handle;

    // Open source.
    if ( ! ( cast( Source!cdrom_paranoia_t )( _source ) ).open( handle ) ) {
      throw new Exception( format( "Failed to open %s", _source.path() ) ); 
    }

    // Something to do?
    if ( _jobs.length == 0 ) {
      logInfo( "Nothing to do." );
      return true;
    }

    // Init some vars.
    long rc;
    short* buffer;
    lsn_t position;

    // Configure paranoia.
    cdio_paranoia_modeset( handle, paranoia_mode_t.PARANOIA_MODE_FULL );


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
      logTrace( "Writer class is " ~ _writerConfig.klass );
      Writer writer = _writerConfig.build( job, disc() );

      if ( writer is null ) {
        logWarning( "Failed to create writer instance!" );
        return false;
      }

      // Heyho, lets go!
      logInfo( "Start job: " ~ job.description() );

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

      // SEEK_SET, SEEK_CUR, SEEK_END are defined in std.c.stdio
      // Note: SEEK_SET seems not to work.
      // Current position?
      position = cdio_paranoia_seek( handle, 0, SEEK_CUR );
      // Go to first sector of range (use relative offset).
      cdio_paranoia_seek( handle, cast( short )( sr.from - position ), SEEK_CUR );
      position = cdio_paranoia_seek( handle, 0, SEEK_CUR );
      // Check result of seeking.
      if ( position != sr.from ) {
        logError(
          format(
            "Failed to seek to sector %d! Stuck at sector %d",
            sr.from,
            position
          )
        );
        continue;
      }

      // Rip data.
      logInfo( "Data is written to " ~ writer.path() ~ "." );
      for ( lsn_t sector = sr.from; sector <= sr.to; sector++ ) {
        // Read sector, max 10 retries.
        buffer = cdio_paranoia_read_limited( handle, null, 10 );

        if ( buffer ) {
          writer.write( cast( ubyte* )( buffer ), CDIO_CD_FRAMESIZE_RAW );
          continue;
        }

        logError( format( "Reading sector %d failed, abort!", sector ) );

        // Set sr.to to last successfully read sector.
        sr.to = cast( lsn_t )( sector - 1 );
        break;
      }

      // Close writer.
      writer.close();
      logInfo( 
        format(
          "Read and wrote %d %s.",
          sr.length(),
          "sector".pluralize( sr.length() )
        )
      );
    }

    return true;
  }


  mixin CdIoAudioDiscReader;
  mixin introspection.Override;
  mixin Log;
}

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
import readers.mixins;
import sources.base;
import utils;
import writers.base;


class SimpleAudioDiscReader : AbstractAudioDiscReader
{
public:
  override void setSource( GenericSource source )
  {
    // We need access to a CdIo_t pointer! Cast is required.
    if ( cast( Source!CdIo_t )( source ) is null ) {
      throw new Exception( format( "%s is no %", source.path(), typeid( Source!CdIo_t ) ) ); 
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
    // Handle.
    CdIo_t* handle;

    // Open source.
    if ( ! ( cast( Source!CdIo_t )( _source ) ).open( handle ) ) {
      throw new Exception( format( "Failed to open %s", _source.path() ) ); 
    }

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
      logTrace( "Writer class is " ~ _writerConfig.klass );
      Writer writer = _writerConfig.build( job, disc() );

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
        rc = cdio_read_audio_sector( handle, buffer.ptr, sector );        
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


  mixin CdIoAudioDiscReader;
  mixin introspection.Override;
  mixin Log;
}

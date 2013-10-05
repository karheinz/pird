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

import checkers.base;
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

    // Set speed of device/image?
    if ( _speed ) {
      if ( ! _source.hasProgrammableSpeed() ) {
        logWarning( "Source does not support setting the speed! Trying anyway." );
      }

      if ( cdio_set_speed( handle, _speed ) == driver_return_code.DRIVER_OP_SUCCESS ) {
        logInfo( format( "Set drive speed to %d.", _speed ) );
      } else {
        logError( format( "Failed to set drive speed to %d", _speed ) );
        return false;
      }
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
      ubyte[] rawBuffer = new ubyte[ CDIO_CD_FRAMESIZE_RAW ];
      ubyte[] buffer = new ubyte[ CDIO_CD_FRAMESIZE_RAW ];
      SectorRange sr = job.sectorRange( disc() );

      // Tell writer how much bytes (expected) to be written.
      writer.setExpectedSize( sr.length() * CDIO_CD_FRAMESIZE_RAW );

      // Open writer.
      writer.open();
      
      // FIXME
      sr.offset = 6;
      // Rip!
      logInfo(
          format(
            "Try to read %d %s starting at sector %d (offset %d samples).",
            sr.length(),
            "sector".pluralize( sr.length() ),
            sr.from,
            sr.offset
          )
        );
      logInfo( "Data is written to " ~ writer.path() ~ "." );

      ulong checkId = 0;
      // Init check if checker was set and job is to read a single track.
      if ( _checker !is null && job.track() > 0 ) {
        checkId = _checker.init( disc(), job.track() );
        logInfo( "checker init" );
      }

      uint bytesWritten;
      uint currentSector;
      uint overallSectors = sr.length();
      logRatio( 0, 0, overallSectors );

      for ( lsn_t sector = sr.fromWithOffset(); sector <= fmin( sr.toWithOffset(), disc().audioSectors() - 1 ); sector++ ) {
        // Only update status bar after each read second (75 sectors).
        currentSector++;
        if ( currentSector % CDIO_CD_FRAMES_PER_SEC == 0 ) {
          logRatio(
            currentSector,
            currentSector - CDIO_CD_FRAMES_PER_SEC,
            overallSectors
          );
        } else if ( currentSector == overallSectors ) {
          logRatio(
            currentSector,
            currentSector - ( overallSectors % CDIO_CD_FRAMES_PER_SEC ),
            overallSectors
          );
        }

        // Read sector.
        rc = cdio_read_audio_sector( handle, rawBuffer.ptr, sector );        
        if ( rc == driver_return_code.DRIVER_OP_SUCCESS ) {
          if ( _swap ) {
            DiscReader.swapBytes( rawBuffer );
          }

          // Fill non-empty buffer.
          if ( bytesWritten > 0 )
          {
            for ( uint i = 0; i < ( sr.offset * 4 ); ++i ) {
              buffer[ bytesWritten++ ] = rawBuffer[ i ]; 
            }
          }

          // Full buffer? Write and check!
          if ( bytesWritten == buffer.length ) {
            //writer.write( buffer );

            // Feed check with data.
            if ( checkId > 0 ) { _checker.feed( checkId, sector, buffer ); }

            // Reset!
            bytesWritten = 0;
          }

          // Write to empty buffer.
          for ( uint i = ( sr.offset * 4 ); i < rawBuffer.length; ++i ) {
            buffer[ bytesWritten++ ] = rawBuffer[ i ]; 
          }

          // Full buffer? Write and check!
          if ( bytesWritten == buffer.length ) {
            //writer.write( buffer );

            // Feed check with data.
            if ( checkId > 0 ) { _checker.feed( checkId, sector, buffer ); }

            // Reset!
            bytesWritten = 0;
          }

          continue;
        }

        logError( "", true, false );
        logError( format( "Reading sector %d failed: %s, abort!", sector, to!string( rc ) ) );

        // Set sr.to to last successfully read sector.
        sr.to = cast( lsn_t )( sector - 1 );
        break;
      }

      // Close writer.
      writer.close();
      logInfo( format( "Read and wrote %d %s.", sr.length(), "sector".pluralize( sr.length() ) ) );

      // Finish check.
      if ( checkId > 0 ) {
        string result;
        if ( _checker.finish( checkId, result ) ) {
          logInfo( format( "Check was successfull: %s", result ) );
        } else {
          logError( format( "Check failed: %s", result ) );
        }
      }
    }

    return true;
  }

  mixin CdIoAudioDiscReader;
  mixin introspection.Override;
  mixin Log;

protected:
  mixin RatioLogger; 
}

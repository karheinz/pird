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
        if ( cast( Source!CdIo_t )( source ) is null )
        {
            throw new Exception( format( "%s is no %", source.path(), typeid( Source!CdIo_t ) ) );
        }
        _source = source;
        _disc   = null;
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
        if ( !( cast( Source!CdIo_t )( _source ) ).open( handle ) )
        {
            throw new Exception( format( "Failed to open %s", _source.path() ) );
        }

        // Something to do?
        if ( _jobs.length == 0 )
        {
            logInfo( "Nothing to do." );
            return true;
        }

        // Set speed of device/image?
        if ( _speed )
        {
            if ( !_source.hasProgrammableSpeed() )
            {
                logWarning( "Source does not support setting the speed! Trying anyway." );
            }

            if ( cdio_set_speed( handle, _speed ) == driver_return_code.DRIVER_OP_SUCCESS )
            {
                logInfo( format( "Set drive speed to %d.", _speed ) );
            }
            else
            {
                logError( format( "Failed to set drive speed to %d", _speed ) );
                return false;
            }
        }

        // Add calibration job (read first track).
        if ( _checker !is null )
        {
            _jobs.insertInPlace( 0, new ReadFromAudioDiscJob( 1 ) );
        }

        ReadFromDiscJob job;
        while ( _jobs.length )
        {
            job = _jobs.front();
            _jobs.popFront();

            // Check if job fits disc.
            if ( !job.fits( disc() ) )
            {
                logWarning( "Job is unapplicable to disc: " ~ job.description() );
                logWarning( "Skip job: " ~ job.description() );
                continue;
            }

            // Check if writer is available.
            if ( _checker is null || _checker.isCalibrated() )
            {
                logTrace( "Writer class is " ~ _writerConfig.klass );
            }
            Writer writer = _writerConfig.build( job, disc() );

            if ( writer is null )
            {
                logWarning( "Failed to create writer instance!" );
                return false;
            }

            // Heyho, lets go!
            if ( _checker !is null && ! _checker.isCalibrated() )
            {
                logInfo( "Start calibration of " ~ _source.path() ~ ": " ~ job.description() );
            }
            else
            {
                logInfo( "Start job: " ~ job.description() );
            }

            // Init some vars.
            driver_return_code_t rc;
            ubyte[] buffer          = new ubyte[ Checker.SECTORS_TO_READ * CDIO_CD_FRAMESIZE_RAW ];
            ubyte[] bufferWithZeros = new ubyte[ CDIO_CD_FRAMESIZE_RAW ];
            ubyte[][ Checker.SECTORS_TO_READ ] bufferViews = [
                buffer[ (  0 * CDIO_CD_FRAMESIZE_RAW ) .. (  1 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  1 * CDIO_CD_FRAMESIZE_RAW ) .. (  2 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  2 * CDIO_CD_FRAMESIZE_RAW ) .. (  3 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  3 * CDIO_CD_FRAMESIZE_RAW ) .. (  4 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  4 * CDIO_CD_FRAMESIZE_RAW ) .. (  5 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  5 * CDIO_CD_FRAMESIZE_RAW ) .. (  6 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  6 * CDIO_CD_FRAMESIZE_RAW ) .. (  7 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  7 * CDIO_CD_FRAMESIZE_RAW ) .. (  8 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  8 * CDIO_CD_FRAMESIZE_RAW ) .. (  9 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ (  9 * CDIO_CD_FRAMESIZE_RAW ) .. ( 10 * CDIO_CD_FRAMESIZE_RAW ) ],
                buffer[ ( 10 * CDIO_CD_FRAMESIZE_RAW ) .. ( 11 * CDIO_CD_FRAMESIZE_RAW ) ]
            ];


            SectorRange sr = job.sectorRange( disc() );

            // Tell writer how much bytes (expected) to be written.
            writer.setExpectedSize( sr.length() * CDIO_CD_FRAMESIZE_RAW );

            // Open writer.
            if ( _checker is null || _checker.isCalibrated() )
            {
                writer.open();
                logInfo( "Writer was opened." ); 
            }

            // Rip!
            logInfo(
                format(
                    "Try to read %d %s starting at sector %d.",
                    sr.length(),
                    "sector".pluralize( sr.length() ),
                    sr.from
                    )
                );

            if ( _checker !is null && _checker.isCalibrated() )
            {
                logInfo( format( "Source %s is calibrated with offset of %d samples.",
                    _source.path(), _checker.getOffset() ) );
            }

            if ( _checker is null || _checker.isCalibrated() )
            {
                logInfo( "Data is written to " ~ writer.path() ~ "." );
            }

            // Init check if checker was set and job is to read a single track.
            ulong checkId = 0;
            if ( _checker !is null && job.track() > 0 )
            {
                checkId = _checker.init( disc(), job.track() );
                logInfo( "Initialized checker." );
            }

            uint currentSector;
            uint overallSectors = sr.length() + ( 2 * Checker.MAX_SECTORS_OFFSET );
            logRatio( 0, 0, overallSectors );

            // Read +/- Checker.MAX_SECTORS_OFFSET sectors.
            for ( lsn_t sector = ( sr.from - Checker.MAX_SECTORS_OFFSET );
                  sector <= ( sr.to + Checker.MAX_SECTORS_OFFSET );
                  sector++
                )
            {
                ++currentSector;

                // Only update status bar after each read second (75 sectors).
                if ( currentSector % CDIO_CD_FRAMES_PER_SEC == 0 )
                {
                    logRatio(
                        currentSector,
                        currentSector - CDIO_CD_FRAMES_PER_SEC,
                        overallSectors
                        );
                }
                else if ( currentSector == overallSectors )
                {
                    logRatio(
                        currentSector,
                        currentSector - ( overallSectors % CDIO_CD_FRAMES_PER_SEC ),
                        overallSectors
                        );
                }

                // Handle pseudo sectors at the beginning.
                if ( sector < 0 )
                {
                    continue;
                }

                // Shift bufferViews!
                ubyte[] tmp = bufferViews[ 0 ];
                for ( uint i = 1; i < Checker.SECTORS_TO_READ; ++i )
                {
                    bufferViews[ i - 1 ] = bufferViews[ i ];
                }
                bufferViews[ Checker.SECTORS_TO_READ - 1 ] = tmp;

                // Read next sector!
                if ( sector >= disc.audioSectors() )
                {
                    bufferViews[ Checker.SECTORS_TO_READ - 1 ] = bufferWithZeros;
                }
                else
                {
                    rc = cdio_read_audio_sector( handle, bufferViews[ Checker.SECTORS_TO_READ - 1 ].ptr, sector );
                    if ( rc != driver_return_code.DRIVER_OP_SUCCESS )
                    {
                        logError( format( "Reading sector %d failed: %s, abort!", sector, to!string( rc ) ) );

                        // Set sr.to to last successfully read sector.
                        sr.to = cast( lsn_t )( sector - 1 );
                        break;
                    }
                }

                logDebug( format( "Read sector %d", sector ) );
                if ( _swap )
                {
                    DiscReader.swapBytes( bufferViews[ Checker.SECTORS_TO_READ - 1 ] );
                }

                // Feed check with data.
                if ( currentSector >= Checker.SECTORS_TO_READ )
                {
                    if ( checkId > 0 )
                    {
                        _checker.feed( checkId, sector - Checker.MAX_SECTORS_OFFSET, bufferViews );
                    }
                }

                // Write to file!
                if ( _checker is null || _checker.isCalibrated() )
                {
                    // Prepare buffers covering sector.
                    // Two buffers covering CDIO_CD_FRAMESIZE_RAW bytes are returned.
                    ulong     byteOffset = Checker.SAMPLE_SIZE * ( _checker is null ? 0 :_checker.getOffset() );
                    ubyte[][] buffers;
                    while ( length( buffers ) < CDIO_CD_FRAMESIZE_RAW )
                    {
                        if ( !buffers.length )
                        {
                            buffers ~= cast( ubyte[] )bufferViews
                            [ ( Checker.MAX_SECTORS_OFFSET * CDIO_CD_FRAMESIZE_RAW +
                                byteOffset ) / CDIO_CD_FRAMESIZE_RAW ]
                            [ ( Checker.MAX_SECTORS_OFFSET * CDIO_CD_FRAMESIZE_RAW +
                                byteOffset ) % CDIO_CD_FRAMESIZE_RAW .. $ ];
                        }
                        else
                        {
                            buffers ~= cast( ubyte[] )bufferViews
                                [ ( Checker.MAX_SECTORS_OFFSET * CDIO_CD_FRAMESIZE_RAW +
                                    byteOffset + length( buffers ) ) / CDIO_CD_FRAMESIZE_RAW ]
                                [ 0 .. ( CDIO_CD_FRAMESIZE_RAW - length( buffers ) ) ];
                        }
                    }

                    foreach( buf; buffers )
                    {
                        writer.write( buf );
                    }
                }
            }

            // Close writer.
            if ( _checker is null || _checker.isCalibrated() )
            {
                writer.close();
                logInfo( format( "Read and wrote %d %s.", sr.length(), "sector".pluralize( sr.length() ) ) );
            }
            else
            {
                logInfo( format( "Read %d %s.", sr.length(), "sector".pluralize( sr.length() ) ) );
            }

            // Finish check.
            if ( checkId > 0 )
            {
                // After finish was called the first time the checker should be calibrated.
                string result;
                if ( _checker.finish( checkId, result ) )
                {
                    logInfo( format( "Check was successfull: %s", result ) );
                }
                else
                {
                    logError( format( "Check failed: %s", result ) );
                }

                // Abort if calibration failed (first job).
                if ( ! _checker.isCalibrated() )
                {
                    logError( "Calibration failed, please specify the drive offset in samples or try another disc!" );
                    return false;
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

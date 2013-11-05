/+
  Copyright (C) 2013 Karsten Heinze <karsten@sidenotes.de>

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

module checkers.accurate;

import core.exception;
import std.c.string;
import std.conv;
import std.exception;
import std.file;
import std.math;
import std.path;
import std.random;
import std.regex;
import std.signals;
import std.socket;
import std.stdio;
import std.stream;
import std.string;

import c.cdio.sector;
import c.cdio.types;
import checkers.base;
import introspection;
import log;
import media;
import utils;


/**
 * The disc identifier used by accurate rip.
 */
struct DiscIdent
{
    ubyte tracks;
    uint  trackOffsetsSum;
    uint  trackOffsetsProduct;
    uint  cddbDiscId;

    this( in ubyte[] data )
    {
        tracks = data[ 0 ];

        // FIXME: Works only on LE systems.
        memcpy( &trackOffsetsSum, &( data[ 1 ] ), trackOffsetsSum.sizeof );
        memcpy( &trackOffsetsProduct, &( data[ 5 ] ), trackOffsetsProduct.sizeof );
        memcpy( &cddbDiscId, &( data[ 9 ] ), cddbDiscId.sizeof );
    }

    bool opEquals( T ) ( auto ref T other )
    {
        return tracks == other.tracks &&
               trackOffsetsSum == other.trackOffsetsSum &&
               trackOffsetsProduct == other.trackOffsetsProduct &&
               cddbDiscId == other.cddbDiscId;
    }
}

/**
 * The track data used by accurate rip.
 */
struct TrackData
{
    ubyte confidence;
    uint  crc;
    int   offset;

    this( in ubyte[] data )
    {
        confidence = data[ 0 ];

        // FIXME: Works only on LE systems.
        memcpy( &crc, &( data[ 1 ] ), crc.sizeof );
        memcpy( &offset, &( data[ 5 ] ), offset.sizeof );
    }
}

/**
 * The track CRC data.
 */
struct CrcData
{
    uint factor = 1;
    uint crc;
}

/**
 * The accurate check data of a track.
 */
struct AccurateCheckData
{
    Disc  disc;
    ubyte track; // starts with 1
    bool  isLastTrack = false;
    CrcData[ int ] crcByOffset;
    string    url;
    string  proto = "http";
    string   host = "www.accuraterip.com";
    ushort   port = 80;
    string   path;
    DiscIdent discIdent;

    this( Disc d, ubyte t )
    {
        disc  = d;
        track = t;

        // Is last track?
        Track[] tracks = d.audioTracks();
        foreach_reverse ( elem; tracks )
        {
            if ( !elem.isAudio() )
            {
                continue;
            }

            if ( elem.number() == track )
            {
                isLastTrack = true;
            }
            break;
        }

        // Calc DiscIdent and URL.
        lsn_t        tmp;
        uint         trackOffsetsSum;
        uint         trackOffsetsProduct;
        string       trackOffsetsSumAsHexString;

        // NOTE: lsn is lba in libcdio, see this discussion:
        //   http://lists.gnu.org/archive/html/libcdio-devel/2012-11/msg00010.html
        foreach ( i, track; tracks )
        {
            tmp                  = track.sectorRange.from;
            trackOffsetsSum     += tmp;
            trackOffsetsProduct += ( ( tmp != 0 ? tmp : 1 ) * ( i + 1 ) );
        }
        // Lead out too. Consider data track!
        tmp                        = disc.tracks()[ $ - 1 ].sectorRange.to + 1;
        trackOffsetsSum           += tmp;
        trackOffsetsProduct       += ( ( tmp != 0 ? tmp : 1 ) * ( tracks.length + 1 ) );
        trackOffsetsSumAsHexString = format( "%08x", trackOffsetsSum );

        // Set members.
        discIdent.tracks              = cast( ubyte )tracks.length;
        discIdent.trackOffsetsSum     = trackOffsetsSum;
        discIdent.trackOffsetsProduct = trackOffsetsProduct;
        discIdent.cddbDiscId          = media.cddbDiscId( disc );

        path = format(
            "/accuraterip/%c/%c/%c/dBAR-%03d-%08x-%08x-%08x.bin",
            trackOffsetsSumAsHexString[ 7 ],
            trackOffsetsSumAsHexString[ 6 ],
            trackOffsetsSumAsHexString[ 5 ],
            tracks.length,
            trackOffsetsSum,
            trackOffsetsProduct,
            discIdent.cddbDiscId
            );

        url = format(
            "%s://%s:%d%s",
            proto,
            host,
            port,
            path
            );
    }
}

/**
 * An instance of this class is used to check
 * wether tracks were ripped accurately.
 *
 * http://accuraterip.com
 */
class AccurateChecker : Checker
{
private:
    /** known sample offsets */
    static const int[] OFFSETS = [
            -582,
            0,
            6,
            12,
            48,
            91,
            97,
            102,
            108,
            120,
            564,
            594,
            667,
            685,
            691,
            704,
            738,
            1194,
            1292,
            1336,
            1776
        ];

    /** accurate check data by id */
    AccurateCheckData[ ulong ] _data;

    /** offset of the underlying source */
    int _offset;

    /** offsets to use */
    int[] _offsets = OFFSETS;

    /** is underlying source calibrated */
    bool _calibrated;

public:
    ulong init( Disc disc, in ubyte track )
    {
        AccurateCheckData data = AccurateCheckData( disc, track );

        if ( ! fetchAccurateRipResults( data ) )
        {
            return 0L;
        }

        // Generate random id as lookup key.
        ulong id = uniform!( ulong )();

        foreach ( offset; _offsets )
        {
            data.crcByOffset[ offset ] = CrcData();
        }

        _data[ id ] = data;
        return id;
    }

    void feed(
        in ulong id,
        in lsn_t sector,
        in ubyte[][ SECTORS_TO_READ ] data
        )
    {
        try
        {
            AccurateCheckData d = _data[ id ];

            // Ignore first 5 sectors of disc (except last byte of 5th sector) and
            // last 5 sectors of disc (consider only audio tracks).
            bool ignore = (
                ( d.track == 1 && sector < 5 ) ||
                ( d.isLastTrack && sector > ( d.disc.tracks[ d.track - 1 ].sectorRange().to - 5 ) )
                );


            foreach ( offset; _offsets )
            {
                CrcData crcData = d.crcByOffset[ offset ];

                // Prepare buffers covering sector.
                // Two buffers covering CDIO_CD_FRAMESIZE_RAW bytes are returned.
                ulong     byteOffset = SAMPLE_SIZE * offset;
                ubyte[][] buffers;
                while ( length( buffers ) < CDIO_CD_FRAMESIZE_RAW )
                {
                    if ( !buffers.length )
                    {
                        buffers ~= cast( ubyte[] )data
                        [ ( MAX_SECTORS_OFFSET * CDIO_CD_FRAMESIZE_RAW +
                            byteOffset ) / CDIO_CD_FRAMESIZE_RAW ]
                        [ ( MAX_SECTORS_OFFSET * CDIO_CD_FRAMESIZE_RAW +
                            byteOffset ) % CDIO_CD_FRAMESIZE_RAW .. $ ];
                    }
                    else
                    {
                        buffers ~= cast( ubyte[] )data
                        [ ( MAX_SECTORS_OFFSET * CDIO_CD_FRAMESIZE_RAW +
                            byteOffset + length( buffers ) ) / CDIO_CD_FRAMESIZE_RAW ]
                        [ 0 .. CDIO_CD_FRAMESIZE_RAW - length( buffers ) ];
                    }
                }

                // Now calc the checksum.
                uint  tmp;
                ubyte read;
                foreach ( i, buffer; buffers )
                {
                    foreach ( k, elem; buffer )
                    {
                        ++read;

                        // Handle sector.
                        if ( !ignore )
                        {
                            *( cast( ubyte* )( &tmp ) + read - 1 ) = elem;

                            if ( read == 4 )
                            {
                                crcData.crc += ( crcData.factor * tmp );
                            }
                        }
                        // Also handle last sample of 5th sector,
                        // which is found at the end of second buffer.
                        else if ( sector == 4 && i == ( buffers.length - 1 ) && k >= ( buffer.length - 4 ) )
                        {
                            // FIXME: Byte order save!
                            *( cast( ubyte* )( &tmp ) + read - 1 ) = elem;

                            if ( read == 4 )
                            {
                                crcData.crc += ( crcData.factor * tmp );
                            }
                        }

                        if ( read == 4 )
                        {
                            ++( crcData.factor );
                            read = 0;
                        }
                    }
                }

                // Store crcData, because structs are copied by value!
                d.crcByOffset[ offset ] = crcData;
            }

            // Store d, because structs are copied by value!
            _data[ id ] = d;
        }
        catch ( RangeError e )
        {
            // Log a range violation.
            logError( format(
                    "either check %ul was not found or track is not part of disc", id
                    ) );
        }
    }

    bool finish( in ulong id, out string result )
    {
        try
        {
            AccurateCheckData d = _data[ id ];
            result = "";
            TrackData[] matches;

            foreach ( offset; _offsets )
            {
                ubyte dbuffer[ 13 ];  // don't use DiscIdent.sizeof because of alignment
                ubyte tbuffer[ 9 ];   // don't use TrackData.sizeof because of alignment

                auto file = std.stdio.File( buildPath( tempDir(), baseName( d.path ) ), "rb" );

                bool match;
                while ( !file.eof )
                {
                    file.rawRead( dbuffer );

                    DiscIdent discIdent = DiscIdent( dbuffer );
                    match = ( discIdent == d.discIdent );
                    for ( uint i = 0; i < discIdent.tracks; ++i )
                    {
                        file.rawRead( tbuffer );

                        if ( match && ( i + 1 ) == d.track )
                        {
                            TrackData trackData = TrackData( tbuffer );
                            if ( d.crcByOffset[ offset ].crc == trackData.crc )
                            {
                                // FIXME: Offset in files seems to be wrong, so overwrite!
                                trackData.offset = offset;
                                matches ~= trackData;
                            }
                        }
                    }
                }
            }

            if ( matches.length == 1 )
            {
                result ~= format( "Track %d was ripped accurately (confidence %d).",
                    d.track, matches[ 0 ].confidence );

                if ( ! _calibrated )
                {
                    _offset = matches[ 0 ].offset;
                    _offsets = [ _offset ];
                    _calibrated = true;
                }
            }
            else if ( matches.length == 0 )
            {
                result ~= format( "Track %d wasn't ripped accurately.", d.track );
            }
            else
            {
                result ~= format( "Track %d was ripped accurately, but offset is not clear.", d.track );
            }

            return ( matches.length == 1 );
        }
        catch ( RangeError e )
        {
            result = format( "check %ul was not found", id );
            return false;
        }
        catch ( ErrnoException e )
        {
            result = "failed to open file";
            return false;
        }
        catch ( ReadException e )
        {
            result = "failed to read from file";
            return false;
        }
    }

    void calibrate( int offset )
    {
        _offset = offset;
        _offsets = [ _offset ];
        _calibrated = true;
    }

    bool isCalibrated()
    {
        return _calibrated;
    }

    int getOffset()
    {
        return _offset;
    }

    mixin introspection.Initial;
    mixin Log;

private:
    bool fetchAccurateRipResults( AccurateCheckData data )
    {
        string path = buildPath( tempDir(), baseName( data.path ) );

        try
        {
            if ( path.isFile )
            {
                return true;
            }
            else
            {
                return false;
            }
        }
        catch ( FileException e )
        {
        }

        Socket socket = new TcpSocket();
        socket.setOption( SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"( 1 ) );
        socket.connect( new InternetAddress( cast( char[] )data.host, data.port ) );
        scope( exit ) socket.close();
        socket.send( format( "GET %s HTTP/1.1\r\nHost: %s\r\n\r\n", data.path, data.host ) );

        void buffer[] = new ubyte[ 1024 ];
        ubyte toWrite[];
        ptrdiff_t bytes;
        bool receivedData;
        while ( true )
        {
            bytes = socket.receive( buffer );
            if ( bytes > 0 )
            {
                toWrite ~= cast( ubyte[] )buffer[ 0 .. bytes ];
                receivedData = true;
            }
            else
            {
                break;
            }
        }

        if ( ! receivedData )
        {
            return false;
        }

        // Check http header.
        auto pattern = regex( r" 200( |$)" );
        ptrdiff_t eol = indexOf( cast( char[] )toWrite, '\n' );
        string header = to!string( stripRight( cast( char[] )( toWrite[ 0 .. eol ] ) ) );
        
        auto hit = match( header, pattern );
        if ( hit.empty() )
        {
            return false;
        }

        // Write to file (remove http header)!
        ulong start = 0;
        ubyte delimiter[] = [ '\r', '\n', '\r', '\n' ];
        for ( ulong i = 0; i < ( toWrite.length - delimiter.length ); ++i )
        {
            if ( toWrite[ i .. i + delimiter.length ] == delimiter )
            {
                start = i + delimiter.length;
                break;
            }
        }
        auto file = std.stdio.File( path, "wb" );
        file.rawWrite( toWrite[ start .. $ ] );
        
        return true;
    }
}


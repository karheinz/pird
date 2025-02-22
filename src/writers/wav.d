/+
  Copyright (C) 2011-2025 Karsten Heinze <karsten@sidenotes.de>

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

module writers.wav;

import core.stdc.string;

import std.algorithm.comparison;
import std.bitmanip;
import std.conv;
import std.math;
import std.stdio;
import std.string;
import std.system;

static import introspection;
static import writers.base;


/**
 * For Structure see: http://de.wikipedia.org/wiki/RIFF_WAVE (german).
 *
 * Byte order is little endian by definition.
 */
struct WavHeader
{
    char[ 4 ] chunkId = "RIFF";
    uint chunkSize = 44 - 8;
    char[ 4 ] riffType = "WAVE";
    char[ 4 ] fmtTag   = "fmt ";
    uint fmtHeaderLength = 16;
    // PCM is 0x0001.
    ushort fmtType       = 0x0001;
    ushort fmtChannels   = 2;
    uint   fmtSampleRate = 44100;
    // Bytes per second is rate * channels * quantification.
    uint fmtBytesPerSecond = 44100 * 2 * ushort.sizeof;
    // Block align is channels * ( ( <bits/sample> + 7 ) / 8 )
    ushort fmtBlockAlign    = 2 * ( ( ushort.sizeof * 8 + 7 ) / 8 );
    ushort fmtBitsPerSample = ushort.sizeof * 8;
    char[ 4 ] dataTag = "data";
    uint dataLength = 0;

    this( File file )
    {
        chunkSize  = cast( uint )( file.size - 8 );
        dataLength = cast( uint )( file.size - 44 );
    }

    void setExpectedSize( ulong bytes )
    {
        chunkSize  = cast( uint )( bytes + 44 - 8 );
        dataLength = cast( uint )( bytes );
    }

    ubyte[] serialized()
    {
        ubyte[] bytes;
        bytes.length = 44;

        // Convert struct to bytes.
        size_t index = 0;
        memcpy( bytes.ptr + index, chunkId.ptr, 4 );
        index += 4;
        std.bitmanip.write!( uint, Endian.littleEndian, ubyte[] )( bytes, chunkSize, &index );
        memcpy( bytes.ptr + index, riffType.ptr, 4 );
        index += 4;
        memcpy( bytes.ptr + index, fmtTag.ptr, 4 );
        index += 4;
        std.bitmanip.write!( uint, Endian.littleEndian, ubyte[] )( bytes, fmtHeaderLength, &index );
        std.bitmanip.write!( ushort, Endian.littleEndian, ubyte[] )( bytes, fmtType, &index );
        std.bitmanip.write!( ushort, Endian.littleEndian, ubyte[] )( bytes, fmtChannels, &index );
        std.bitmanip.write!( uint, Endian.littleEndian, ubyte[] )( bytes, fmtSampleRate, &index );
        std.bitmanip.write!( uint, Endian.littleEndian, ubyte[] )( bytes, fmtBytesPerSecond, &index );
        std.bitmanip.write!( ushort, Endian.littleEndian, ubyte[] )( bytes, fmtBlockAlign, &index );
        std.bitmanip.write!( ushort, Endian.littleEndian, ubyte[] )( bytes, fmtBitsPerSample, &index );
        memcpy( bytes.ptr + index, dataTag.ptr, 4 );
        index += 4;
        std.bitmanip.write!( uint, Endian.littleEndian, ubyte[] )( bytes, dataLength, &index );

        return bytes.dup;
    }
}

class FileWriter : writers.base.FileWriter
{
    override void close()
    {
        open();

        // Got to the start of the file.
        _file.seek( 0, SEEK_SET );
        // Write header.
        super.write( WavHeader( _file ).serialized() );

        super.close();
    }

    override void write( ubyte* buffer, uint bytes )
    {
        open();

        // Let 44 bytes for the wav header!
        if ( _file.tell() == 0 )
        {
            _file.seek( 44, SEEK_SET );
        }

        super.write( buffer, bytes );
    }

    override void write( ubyte[] buffer )
    {
        open();

        // Let 44 bytes for the wav header!
        if ( _file.tell() == 0 )
        {
            _file.seek( 44, SEEK_SET );
        }

        super.write( buffer );
    }

    override void write( ubyte[] buffer, uint bytes )
    {
        open();

        // Let 44 bytes for the wav header!
        if ( _file.tell() == 0 )
        {
            _file.seek( 44, SEEK_SET );
        }

        super.write( buffer, bytes );
    }

    mixin introspection.Override;
}

class StdoutWriter : writers.base.StdoutWriter
{
protected:
    bool _headerWritten;

public:
    override void write( ubyte[] buffer )
    {
        if ( !_headerWritten )
        {
            if ( _expectedSize == 0 )
            {
                throw new Exception( "Expected file size is required" );
            }

            // Write header.
            WavHeader rawHeader = WavHeader();
            rawHeader.setExpectedSize( _expectedSize );
            super.write( rawHeader.serialized() );
            _headerWritten = true;
        }

        super.write( buffer );
    }

    override void write( ubyte[] buffer, uint bytes )
    {
        uint bound = cast( uint ) min( buffer.length, bytes );
        write( buffer[ 0 .. bound ] );
    }

    override void write( ubyte* buffer, uint bytes )
    {
        if ( !_headerWritten )
        {
            if ( _expectedSize == 0 )
            {
                throw new Exception( "Expected file size is required" );
            }

            // Write header.
            WavHeader rawHeader = WavHeader();
            rawHeader.setExpectedSize( _expectedSize );
            super.write( rawHeader.serialized() );
            _headerWritten = true;
        }

        super.write( buffer, bytes );
    }

    mixin introspection.Override;
}

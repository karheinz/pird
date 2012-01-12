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

module writers.wav;

import std.c.string;

import std.conv;
import std.math;
import std.stdio;
import std.stream;
import std.string;

static import introspection;
static import writers.base;


/*
 * For Structure see: http://de.wikipedia.org/wiki/RIFF_WAVE (german).
 */
struct WavHeader
{
  char[ 4 ] chunkId = "RIFF";
  uint chunkSize = 44 - 8;
  char[ 4 ] riffType = "WAVE";
  char[ 4 ] fmtTag = "fmt ";
  uint fmtHeaderLength = 16;
  // PCM is 0x0001.
  ushort fmtType = 0x0001;
  ushort fmtChannels = 2;
  uint fmtSampleRate = 44100;
  // Bytes per second is rate * channels * quantification.
  uint fmtBytesPerSecond = 44100 * 2 * ushort.sizeof;
  // Block align is channels * ( ( <bits/sample> + 7 ) / 8 )
  ushort fmtBlockAlign = 2 * ( ( ushort.sizeof * 8 + 7 ) / 8 );
  ushort fmtBitsPerSample = ushort.sizeof * 8;
  char[ 4 ] dataTag = "data";
  uint dataLength = 0;

  this( std.stream.File file )
  {
    chunkSize = cast( uint )( file.size - 8 );
    dataLength = cast( uint )( file.size - 44 );
  }

  void setExpectedSize( ulong bytes )
  {
    chunkSize = cast( uint )( bytes + 44 - 8 );
    dataLength = cast( uint )( bytes );
  }

  ubyte[] serialized()
  {
    ubyte[ WavHeader.sizeof ] bytes;

    // Convert struct to bytes.
    memcpy( bytes.ptr, &this, WavHeader.sizeof );
    assert( "RIFF" == to!string( cast( char[] )bytes[ 0 .. 4 ] ) );

    return bytes.dup;
  }
}

class FileWriter : writers.base.FileWriter
{
  override void close()
  {
    open();

    // Got to the start of the file.
    _file.seek( 0, SeekPos.Set );
    // Write header.
    ubyte[] header = WavHeader( _file ).serialized();
    _file.writeExact( header.ptr, header.length );

    super.close();
  }

  override void write( ubyte[] buffer )
  {
    open();

    // Let 44 bytes for the wav header!
    if ( _file.seek( 0, SeekPos.Current ) == 0 ) {
      _file.seek( 44, SeekPos.Set );
    }

    super.write( buffer );
  }

  override void write( ubyte[] buffer, uint bytes )
  {
    open();

    // Let 44 bytes for the wav header!
    if ( _file.seek( 0, SeekPos.Current ) == 0 ) {
      _file.seek( 44, SeekPos.Set );
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
    if ( ! _headerWritten ) {
      if ( _expectedSize == 0  ) {
        throw new Exception( "Expected file size is required" );
      }

      // Write header.
      WavHeader rawHeader = WavHeader();
      rawHeader.setExpectedSize( _expectedSize );
      stdout.rawWrite!ubyte( rawHeader.serialized() );
      _headerWritten = true;
    }

    super.write( buffer );
  }

  override void write( ubyte[] buffer, uint bytes )
  {
    uint bound = cast( uint )fmin( buffer.length, bytes );
    write( buffer[ 0 .. bound ] );
  }

  mixin introspection.Override;
}

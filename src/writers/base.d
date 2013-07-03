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

module writers.base;

import std.math;
import std.stdio;
import std.stream;

import eponyms;
static import introspection;
import media;
import parsers;
import readers.jobs;


interface Writer
{
  struct Config
  {
    // Type of writer to use. 
    string klass;
    // Used to generate a filename.
    Eponym eponym;
    // How to open file.
    FileMode mode = FileMode.In | FileMode.OutNew;
    // Swap bytes?
    bool swap = false;

    // Build and configure writer for job and disc.
    Writer build( ReadFromDiscJob job, Disc disc )
    {
      Writer w = cast( Writer )Object.factory( klass );
      // Check that writer object was created.
      if ( w is null ) { return null; }

      w.setPath( eponym.generate( job, disc ) );
      w.setMode( mode );
      w.setSwap( swap );
      return w;
    }
  }

  void setPath( string path );
  string path();
  void setMode( FileMode mode );
  FileMode mode();
  void setSwap( bool swap );
  bool swap();
  // Expected number of bytes to write (excluding header).
  void setExpectedSize( ulong bytes );
  /*
   * // access modes; may be or'ed
   * enum FileMode {
   *   In = 1,
   *   Out = 2,
   *   OutNew = 6, // includes FileMode.Out
   *   Append = 10 // includes FileMode.Out
   * }
   */
  void open();
  void open( FileMode mode );
  void close();
  void write( ubyte[] buffer );
  void write( ubyte[] buffer, uint bytes );
  void write( ubyte* buffer, uint bytes );
  ulong seek( long offset, SeekPos whence );

  final void swapBytes( ubyte* buffer, ulong bytes )
  {
    ubyte tmp;

    for ( uint i = 0; i < bytes; i += 2 ) {
      // Odd number of bytes, shouldn't happen for CD-DA data.
      if ( ( i + 1 ) == bytes ) { break; }

      tmp = buffer[ i ];
      buffer[ i ] = buffer[ i + 1 ];
      buffer[ i + 1 ] = tmp;
    }
  }

  final void swapBytes( ubyte[] buffer )
  {
    if ( buffer.length ) {
      swapBytes( &( buffer[ 0 ] ), buffer.length );
    }
  }
}

abstract class FileWriter : Writer, introspection.Interface
{
protected:
  string _path;
  std.stream.File _file;
  FileMode _mode;
  bool _swap;
  ulong _expectedSize;

public:
  void setPath( string path )
  {
    _path = path;
  }

  string path()
  {
    return _path;
  }

  void setMode( FileMode mode )
  {
    _mode = mode;
  }

  FileMode mode()
  {
    return _mode;
  }

  void setSwap( bool swap )
  {
    _swap = swap;
  }

  bool swap()
  {
    return _swap; 
  }

  void setExpectedSize( ulong bytes )
  {
    _expectedSize = bytes;
  }

  void open()
  {
    open( _mode );
  }

  void open( FileMode mode )
  {
    if ( _file is null ) {
      _file = new std.stream.File( _path, mode );
      return;
    }
    
    if ( ! _file.isOpen ) {
      _file.open( _path, mode );
    }
  }

  void close()
  {
    if ( _file !is null ) { _file.close(); }
  }

  void write( ubyte* buffer, uint bytes )
  {
    open();

    if ( _swap ) { swapBytes( buffer, bytes ); }

    _file.writeExact( buffer, bytes );
  }

  void write( ubyte[] buffer, uint bytes )
  {
    uint bound = cast( uint )fmin( buffer.length, bytes );
    write( buffer[ 0 .. bound ] );
  }
  
  void write( ubyte[] buffer )
  {
    open();

    if ( _swap ) { swapBytes( buffer ); }

    _file.writeExact( buffer.ptr, buffer.length );
  }

  ulong seek( long offset, SeekPos whence )
  {
    open();

    return _file.seek( offset, whence );
  }


  mixin introspection.Initial;
}

abstract class StdoutWriter : Writer, introspection.Interface
{
protected:
  string _path;
  FileMode _mode;
  bool _swap;
  ulong _expectedSize;

public:
  void setPath( string path )
  {
    _path = path;
  }

  string path()
  {
    return _path;
  }

  void setMode( FileMode mode )
  {
    _mode = mode;
  }

  FileMode mode()
  {
    return _mode;
  }

  void setSwap( bool swap )
  {
    _swap = swap;
  }

  bool swap()
  {
    return _swap; 
  }

  void setExpectedSize( ulong bytes )
  {
    _expectedSize = bytes;
  }

  void open()
  {
    open( _mode );
  }

  void open( FileMode mode )
  {
    // Nothing to do, already open.
  }

  void close()
  {
    // Nothing to do, never close.
  }

  void write( ubyte* buffer, uint bytes )
  {
    if ( _swap ) { swapBytes( buffer, bytes ); }

    uint times = bytes / 1024;
    uint rest = bytes % 1024;

    if ( times > 0 ) { 
      fwrite( buffer, 1024, times, stdout.getFP() ); 
    }
    if ( rest > 0 ) {
      fwrite( buffer + ( bytes - rest ), rest, 1, stdout.getFP() ); 
    }
  }

  void write( ubyte[] buffer, uint bytes )
  {
    uint bound = cast( uint )fmin( buffer.length, bytes );
    write( buffer[ 0 .. bound ] );
  }
  
  void write( ubyte[] buffer )
  {
    if ( _swap ) { swapBytes( buffer ); }

    stdout.rawWrite!ubyte( buffer );
  }

  ulong seek( long offset, SeekPos whence )
  {
    // Seeking makes no sence here.
    return 0;
  }

  mixin introspection.Initial;
}

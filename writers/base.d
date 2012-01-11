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

module writers.base;

import std.math;
import std.stdio;
import std.stream;

static import introspection;
import media;
import parsers;
import readers.jobs;


interface Writer
{
  struct Config
  {
    // Type of writer to use. 
    string writerClass;
    // Used to generate a filename.
    FilenameGenerator filenameGenerator;
    // How to open file.
    FileMode fileMode = FileMode.In | FileMode.OutNew;

    // Build and configure writer for job and disc.
    Writer build( ReadFromDiscJob job, Disc disc )
    {
      Writer w = cast( Writer )Object.factory( writerClass );
      // Check that writer object was created.
      if ( w is null ) { return null; };

      w.setPath( filenameGenerator.generate( job, disc ) );
      w.setMode( fileMode );
      return w;
    }
  }

  void setPath( string path );
  string path();
  void setMode( FileMode mode );
  FileMode mode();
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
  ulong seek( long offset, SeekPos whence );
}

class FileWriter : Writer, introspection.Interface
{
protected:
  string _path;
  std.stream.File _file;
  FileMode _mode;
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

  void write( ubyte[] buffer, uint bytes )
  {
    uint bound = cast( uint )fmin( buffer.length, bytes );
    write( buffer[ 0 .. bound ] );
  }
  
  void write( ubyte[] buffer )
  {
    open();

    _file.writeExact( buffer.ptr, buffer.length );
  }

  ulong seek( long offset, SeekPos whence )
  {
    open();

    return _file.seek( offset, whence );
  }


  mixin introspection.Initial;
}

class StdoutWriter : Writer, introspection.Interface
{
protected:
  string _path;
  FileMode _mode;
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

  void write( ubyte[] buffer, uint bytes )
  {
    uint bound = cast( uint )fmin( buffer.length, bytes );
    write( buffer[ 0 .. bound ] );
  }
  
  void write( ubyte[] buffer )
  {
    stdout.rawWrite!ubyte( buffer );
  }

  ulong seek( long offset, SeekPos whence )
  {
    // Seeking makes no sence here.
    return 0;
  }

  mixin introspection.Initial;
}

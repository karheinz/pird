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

import std.stream;

static import introspection;


interface Writer
{
  void setPath( string path );
  void setMode( FileMode mode );
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
  ulong seek( long offset, SeekPos whence );
}

abstract class FileWriter : Writer, introspection.Interface
{
protected:
  string _path;
  File _file;
  FileMode _mode;

public:
  void setPath( string path )
  {
    _path = path;
  }

  void setMode( FileMode mode )
  {
    _mode = mode;
  }

  void open()
  {
    open( _mode );
  }

  void open( FileMode mode )
  {
    if ( _file is null ) {
      _file = new File( _path, mode );
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

  void write( ubyte[] buffer )
  {
    open();

    _file.writeExact( cast( const void* )&buffer, buffer.length );
  }

  ulong seek( long offset, SeekPos whence )
  {
    open();

    return _file.seek( offset, whence );
  }
}

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

module sources.base;

import std.array;
import std.conv;
import std.file;
import std.path;
import std.string;

import c.cdio.device;
import c.cdio.logging;
import c.cdio.types;

static import introspection;
import utils;
import sources.mixins;


interface Source : introspection.Interface
{
  string path();
  uint driver();

  bool open();
  bool close();
  CdIo_t* handle();

  bool isDevice();
  bool isImage();

  DirEntry dirEntry();

  string[] aliases();
  void addAlias( string path );

  // Allows to search for all sources.
  mixin Finders;
}

abstract class AbstractSource : Source
{
protected:
  string _path;
  string[] _aliases;
  uint _driver = Driver.UNKNOWN;
  CdIo_t* _handle;
    
  void addAlias( string path ) {
    _aliases ~= path;
  }

public:
  final CdIo_t* handle() {
    return _handle;
  }

  final string path() {
    return _path;
  }

  final uint driver() {
    return _driver;
  }

  final bool open() {
    _handle = cdio_open( toStringz( _path ), _driver );
    return _handle != null;
  }

  final bool close() {
    if ( _handle == null ) return false;

    // Free memory.
    cdio_destroy( _handle );
    _handle = null;

    return true;
  }

  final bool isDevice() {
    return cdio_is_device( cast( char* )toStringz( _path ), _driver );
  }

  final bool isImage() {
    return !isDevice();
  }

  final DirEntry dirEntry() {
    return std.file.dirEntry( _path );
  }

  final string[] aliases() {
    return _aliases;
  }
}


class Image : AbstractSource
{
  mixin Constructors;
  mixin Finders;
  mixin introspection.Initial;
  mixin Comparators;
}

class Device : AbstractSource
{
  mixin Constructors;
  mixin Finders;
  mixin introspection.Initial;
  mixin Comparators;

  struct Capabilities {
    uint read, write, misc;
    bool fetched;
  };

  struct Info {
    string vendor, model, revision;
    bool fetched;
  };

private:
  Capabilities _capabilities;
  Info _info;

protected:
  Capabilities capabilities() {
    if ( _capabilities.fetched ) return _capabilities;

    cdio_get_drive_cap_dev(
      std.string.toStringz( _path ),
      &_capabilities.read,
      &_capabilities.write,
      &_capabilities.misc
    );

    return _capabilities;
  }

public:
  Info info() {
    if ( _info.fetched ) return _info;

    // Device has to be open!
    if ( ! open() ) { return _info; }

    // Fetch data.
    cdio_hwinfo_t data;
    _info.fetched = cdio_get_hwinfo(
        _handle,
        &data
      );

    // Success? Store data.
    if ( _info.fetched ) {
      _info.vendor = bufferTo!string( data.psz_vendor ).strip();
      _info.model = bufferTo!string( data.psz_model ).strip();
      _info.revision = bufferTo!string( data.psz_revision ).strip();
    }

    return _info;
  }
  
  bool readsAudioDiscs() {
    return ( capabilities().read & ReadCapability.CD_DA ) > 0;
  }
}

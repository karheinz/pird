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
import std.string;

import c.cdio.types;
import c.cdio.device;

static import introspection;
import utils;
import sources.mixins;


interface Source : introspection.Interface
{
  string path();
  uint driver();

  bool open();
  bool close();

  bool isDevice();
  bool isImage();
  

  // Allows to search for all sources.
  mixin Finders;

  // Allows comparison of sources.
  mixin Comparators;
}

abstract class Generic : Source
{
protected:
  string _path;
  uint _driver = Driver.UNKNOWN;
  CdIo_t* _handle;
    
public:
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
}


class Image : Generic
{
  mixin Constructors;
  mixin Finders;
  mixin introspection.Implementation;
  mixin Comparators;
}

class Device : Generic
{
  mixin Constructors;
  mixin Finders;
  mixin introspection.Implementation;
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
      _info.vendor = to!string( data.psz_vendor );
      _info.model = to!string( data.psz_model );
      _info.revision = to!string( data.psz_revision );
    }

    return _info;
  }
  
  bool readsAudioDiscs() {
    return ( capabilities().read & ReadCapability.CD_DA ) > 0;
  }
}

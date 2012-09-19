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

module sources.base;

import std.array;
import std.conv;
import std.file;
import std.path;
import std.string;

import c.cdio.cdda;
import c.cdio.device;
import c.cdio.logging;
import c.cdio.paranoia;
import c.cdio.types;

static import introspection;
import utils;
import sources.mixins;



interface GenericSource
{
  string path();
  uint driver();

  bool isDevice();
  bool isImage();

  DirEntry dirEntry();

  string[] aliases();
  void addAlias( string path );
}

interface Source( T ) : GenericSource, introspection.Interface
{
  bool open( out T* handle );
  bool close( out T* handle );

  // Allows to search for all sources.
  mixin Finders;
}

abstract class AbstractSource : Source!CdIo_t
{
protected:
  string _path;
  string[] _aliases;
  uint _driver = Driver.UNKNOWN;
  CdIo_t* _cdio_t_handle;
    
  void addAlias( string path ) {
    _aliases ~= path;
  }

public:
  final string path() {
    return _path;
  }

  final uint driver() {
    return _driver;
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

  bool open( out CdIo_t* handle ) {
    if ( _cdio_t_handle ) {
      handle = _cdio_t_handle;
      return true;
    }

    string cwd;
    try {
      cwd = getcwd();
      chdir( dirName( _path ) );
      handle = _cdio_t_handle = cdio_open( toStringz( baseName( _path ) ), _driver );
      return _cdio_t_handle != null;
    } catch ( Exception e ) {
      handle = null;
      return false;
    } finally {
      chdir( cwd );
    } 
  }

  bool close( out CdIo_t* handle ) {
    handle = null;

    if ( _cdio_t_handle ) {
      // Free memory.
      cdio_destroy( _cdio_t_handle );
      _cdio_t_handle = null;
    }

    return true;
  }
}


class Image : AbstractSource
{
  mixin Constructors;
  mixin Finders;
  mixin introspection.Initial;
  mixin Comparators;
}

class Device : AbstractSource, Source!cdrom_drive_t, Source!cdrom_paranoia_t
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

protected:
  Capabilities _capabilities;
  Info _info;
  cdrom_drive_t* _cdrom_drive_t_handle;
  cdrom_paranoia_t* _cdrom_paranoia_t_handle;

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
  // Need (dummy) overriden methods here, otherwise unittests will fail.
  // Problem arises when different Source interfaces implemented by a class.
  override bool open( out CdIo_t* handle ) {
    return super.open( handle );
  }
  override bool close( out CdIo_t* handle ) {
    return super.close( handle );
  }

  bool open( out cdrom_drive_t* handle ) {
    // Handle exists.
    if ( _cdrom_drive_t_handle ) {
      handle = _cdrom_drive_t_handle;
      // Already opened?
      if ( _cdrom_drive_t_handle.opened ) {
        return true;
      // Try to open.
      } else {
        return ( cdio_cddap_open( _cdrom_drive_t_handle ) == 0 );
      }
    }

    // Get the handle using CdIo_t struct.
    CdIo_t* tmp;
    if ( ! open( tmp ) ) { return false; }

    handle = _cdrom_drive_t_handle = cdio_cddap_identify_cdio( tmp, 0, null );
    if ( _cdrom_drive_t_handle == null ) { return false; }

    // Try to open.
    return ( cdio_cddap_open( _cdrom_drive_t_handle ) == 0 );
  }

  
  bool close( out cdrom_drive_t* handle ) {
    handle = null;

    if ( _cdrom_drive_t_handle ) {
      // Free memory.
      cdio_cddap_close_no_free_cdio( _cdrom_drive_t_handle );
    }

    return true;
  }

  bool open( out cdrom_paranoia_t* handle ) {
    // Handle exists.
    if ( _cdrom_paranoia_t_handle ) {
      handle = _cdrom_paranoia_t_handle;
      return true;
    }

    // Get the handle using cdrom_drive_t struct.
    cdrom_drive_t* tmp;
    if ( ! open( tmp ) ) { return false; }

    handle = _cdrom_paranoia_t_handle = cdio_paranoia_init( tmp );
    return ( _cdrom_paranoia_t_handle != null );
  }

  bool close( out cdrom_paranoia_t* handle ) {
    handle = null;

    if ( _cdrom_paranoia_t_handle ) {
      cdio_paranoia_free( _cdrom_paranoia_t_handle );
    }

    return true;
  }

  Info info() {
    if ( _info.fetched ) return _info;

    // Device has to be open!
    if ( ! open( _cdio_t_handle ) ) { return _info; }

    // Fetch data.
    cdio_hwinfo_t data;
    _info.fetched = cdio_get_hwinfo(
        _cdio_t_handle,
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

unittest {
  CdIo_t* cdio_t_handle;
  cdrom_drive_t* cdrom_drive_t_handle;
  cdrom_paranoia_t* cdrom_paranoia_t_handle;

  // Create device and call open for all three handles.
  Device device = new Device( "/device/does/not/exist", Driver.UNKNOWN );
  assert( device !is null );
  assert( ! device.open( cdio_t_handle ) );
  assert( device.close( cdio_t_handle ) );
  assert( ! device.open( cdrom_drive_t_handle ) );
  assert( device.close( cdrom_drive_t_handle ) );
  assert( ! device.open( cdrom_paranoia_t_handle ) );
  assert( device.close( cdrom_paranoia_t_handle ) );
  assert( cast( Source!CdIo_t )( device ) !is null );
  assert( cast( Source!cdrom_drive_t )( device ) !is null );
  assert( cast( Source!cdrom_paranoia_t )( device ) !is null );

  // Create image and call open for one handle.
  Image image = new Image( "/file/does/not/exist", Driver.UNKNOWN );
  assert( image !is null );
  assert( ! image.open( cdio_t_handle ) );
  assert( image.close( cdio_t_handle ) );
  assert( cast( Source!CdIo_t )( image ) !is null );
}

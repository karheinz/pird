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


module sources.mixins;


mixin template Finders()
{
  alias typeof( this ) T;

  // Direct lookup.
  final static T find( string path ) {
    foreach( source; T.find() ) {
      // Check path.
      if ( source.path() == path ) return source;

      // Check aliases.
      foreach( a; source.aliases() ) {
        if ( a == path ) return source;
      }
    }

    return null;
  }

  final static T[] find() {
    // Available sources, paths used as keys.
    Source[ string ] sourcesByPath;

    uint driver;
    string path;


    // Iterate over drivers.
    for ( driver = Driver.min; driver <= Driver.max; driver++ ) {
      // Ignore abstract drivers.
      if ( driver == Driver.UNKNOWN || driver == Driver.DEVICE ) { continue; }
      // Also ignore drivers not avail on system.
      if ( ! cdio_have_driver( driver ) ) { continue; }


      // Get devices using current driver.
      char** dl = cdio_get_devices( driver );

      // Evaluate result.
      if ( *dl != null ) {
        for ( char** p = dl; *p != null; p++ ) {
          path = to!string( *p );
          // Only add to array if source wasn't added before.
          if ( path !in sourcesByPath ) {
            // Device or file?
            if ( cdio_is_device( *p, driver ) ) {
              sourcesByPath[ path ] = new Device( path, driver );
            } else {
              sourcesByPath[ path ] = new Image( path, driver );
            }
          }
        }

        // Free memory.
        cdio_free_device_list( dl );
      }
    }


    T[] result;
    T[] sources;
    T source;
    T[][] groups;
    bool next;
    
    // Drop sources not of type T.
    sources = convert!( T[] )( sourcesByPath.values );

    // Group sources by inode.
    while ( sources.length ) {
      next = false;

      // Handle last elem.
      source = sources.back();
      sources.popBack();

      // Check if sources inode is already known.
      foreach( ref T[] group; groups ) {
        foreach( ref T member; group ) {
          if ( source.dirEntry().statBuf.st_ino == member.dirEntry().statBuf.st_ino ) {
            group ~= source;
            next = true;
            break;
          }
        }
        if ( next ) break;
      }
      if ( next ) continue;

      // Sources inode isn't known, create a new group.
      if ( source !is null ) {
        T[] group;
        group ~= source;
        groups ~= group;
      }
    }

    // Sort groups. Build result.
    foreach( ref T[] group; groups ) {
      group.sort;

      // Add first source in group to result.
      // Add paths of other sources as alias.
      for ( uint i; i < group.length; i++ ) {
        if ( i == 0 ) {
          result ~= group[ i ];
          continue;
        }

        result.back().addAlias( group[ i ].path() );
      }
    }

    return result;
  }

  final static bool exists( string path ) {
    return ( find( path ) !is null );
  }
}

mixin template Constructors()
{
protected:
  this( string path, uint driver ) {
    _path = path;
    _driver = driver;

    assert( _driver >= Driver.min && _driver <= Driver.max, "Invalide driver!" );
  }
}

mixin template Comparators()
{
  override final bool opEquals( Object other ) {
    if ( cast( Object )this is other ) return true;
    if ( other is null ) return false;

    // Important: Only compare instances of Source!
    auto o = cast( Source )other;
    if ( o is null ) return false;

    // Path and driver have to be equal.
    return ( this.path() == o.path() && this.driver() == o.driver() );
  }

  override final int opCmp( Object other ) {
    if ( cast( Object )this is other ) return 0;
    if ( other is null ) return 1;   // this is greater

    // Important: Only compare instances of Source!
    auto o = cast( Source )other;
    if ( o is null ) return 1;   // this is greater

    // Compare driver, inode, file type (symlink) and path.
    // Because image driver values (uint) are greater than 
    // device driver values (uint), devices come before images.
    if ( driver() > o.driver() ) {
      return 1;    // this is greater
    } else if ( driver() < o.driver() ) {
      return -1;   // this is smaller
    } else {   // equal drivers
      if ( dirEntry().statBuf.st_ino > o.dirEntry().statBuf.st_ino ) {
        return 1;    //this is greater
      } else if ( dirEntry().statBuf.st_ino < o.dirEntry().statBuf.st_ino ) {
        return -1;   //this is smaller
      } else {   // equal inodes
        if ( dirEntry().isSymLink() && ! o.dirEntry().isSymLink() ) {
          return 1;   // this is greater
        } else if ( ! dirEntry().isSymLink() && o.dirEntry().isSymLink() ) {
          return -1;  // this is smaller
        } else {    // equal file type
          if ( path() > o.path() ) {
            return 1;    // this is greater
          } else if ( path() < o.path() ) {
            return -1;   // this is smaller
          } else {
            return 0;
          }
        }
      }
    }
  }
}

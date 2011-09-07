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
      if ( source.path() == path ) return source;
    }

    return null;
  }

  final static T[] find() {
    // Available sources, paths used as keys.
    Source[ string ] sources;

    uint driver;
    string path;
    T[] result;

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
          if ( path !in sources ) {
            // Device or file?
            if ( cdio_is_device( *p, driver ) ) {
              sources[ path ] = new Device( path, driver );
            } else {
              sources[ path ] = new Image( path, driver );
            }
          }
        }

        // Free memory.
        cdio_free_device_list( dl );
      }
    }

    // Return only instances of class T.
    return convert!( T[] )( sources.values ).sort;
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

    // Compare driver and path.
    // Because image driver values (uint) are greater
    // than device driver values (uint), devices come before images.
    if ( driver() > o.driver() ) {
      return 1;    // this is greater
    } else if ( driver() < o.driver() ) {
      return -1;   // this is smaller
    } else {   // equal drivers
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

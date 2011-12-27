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

import std.conv;
import std.file;
import std.stdio;
import std.string;
import std.traits;

import std.c.string;

import c.cdio.device;
import c.cdio.logging;

import commands;
import log;
import parsers;
import sources.base;
import sources.mixins;
import sources.utils;
import utils;


int main( string[] args )
{
  Configuration config;
  Parser parser = new DefaultCommandLineParser();

  if ( ! parser.parse( args, config ) ) {
    // Error message is available here: config.parser.error
    //stderr.writeln( "ERROR: " ~ config.parser.error ~ "\n" );
    stderr.writeln( config.parser.usage );
    return 1;
  }

  CommandFactory commandFactory = new DefaultCommandFactory();
  Command command = commandFactory.build( config ); 

  LoggerFactory loggerFactory = new DefaultLoggerFactory();
  Logger logger = loggerFactory.build( config );
  command.connect( &logger.handleSignal );

  //cdio_debug( toStringz( "Hello" ) );
  return ( command.execute() ? 0 : 1 );

  /+
  Device.Capabilities c;
  writefln( "%032b", c.read );

  Source[] sources = Device.find().generalize() ~ Image.find().generalize();
  // toLower() might by of interest.
  writeln( Source.type().pluralize(), ":" );
  sources.print();

  writeln( Device.type().pluralize(), ":" );
  Device.find().print();
  writeln( Image.type().pluralize(), ":" );
  Image.find().print();

  writeln( Source.type().pluralize(), ":" );
  Source.find().print();

  foreach( source; convert!( Device[] )( Source.find() ) ) {
    writeln( source.path() );
    writeln( "Open ", source.path(), "? ", source.open() );
    writeln( "Close? ", source.path(), "? ", source.close() );

    Device device = cast( Device )source;
    writeln( device.path(), " reads CD-DA? ", device.readsAudioDiscs() );
  }

  writeln( "/dev/cdrom exists as Source? ", Source.exists( "/dev/cdrom" ) );
  writeln( "/dev/cdrom exists as Device? ", Device.exists( "/dev/cdrom" ) );
  writeln( "/dev/cdrom exists as Image? ", Image.exists( "/dev/cdrom" ) );
  +/
}

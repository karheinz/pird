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


module commands;

import std.array;
import std.conv;
import std.file;
import std.signals;
import std.stdio;
import std.string;
import std.variant;

import c.cdio.logging;

static import introspection;
import log;
import media;
import parsers;
import readers.base;
import readers.paranoia;
import readers.simple;
import sources.base;
import sources.utils;
import utils;


class KeyValueStore
{
  protected:
    Variant[ string ] store;

  public:
    void set( string key, Variant value )
    {
      store[ key ] = value;
    }
  
    Variant get( string key )
    {
      return store[ key ];
    }

    bool contains( string key )
    {
      return ( ( key in store ) !is null );
    }

    void clear()
    {
      store.clear();
    }
}

interface Command : introspection.Interface
{
  bool execute();
  void simulate();
  void connect( void delegate( string, LogLevel, string ) signalHandler );
  void disconnect( void delegate( string, LogLevel, string ) signalHandler );
  void emit( string emitter, LogLevel level, string message );
  final void handleSignal( string emitter, LogLevel level, string message ) 
  {
    emit( emitter, level, message );
  }
  void setKeyValueStore( KeyValueStore store );
  KeyValueStore keyValueStore();
}


abstract class AbstractCommand : Command
{
  protected:
    KeyValueStore _store;

  public:
    void setKeyValueStore( KeyValueStore store )
    {
      if ( store is null ) { throw new Exception( "KeyValueStore is null" ); }

      _store = store;
    }

    KeyValueStore keyValueStore()
    {
      if ( _store is null ) { _store = new KeyValueStore(); }

      return _store;
    }

    mixin Log;
}

interface CommandFactory
{
  Command build( Configuration config );
}

class DefaultCommandFactory : CommandFactory
{
  Command build( Configuration config ) {
    // Help requested?
    if ( config.help ) {
      PrintCommand command = new PrintCommand();
      command.enqueue( config.parser.usage ); 
      return command;
    }
    
    // List sources?
    if ( config.list ) {
      // Explore given source.
      if ( config.sourceFile.length ) {
        return new ExploreSourceCommand!Source( config.sourceFile );
      }
      // List images in dir.
      if ( config.sourceDirectory.length ) {
        return new ListSourcesCommand!Image( config.sourceDirectory );
      }
      // List devices.
      return new ListSourcesCommand!Device();
    }

    // Rip disc.
    Command c;
    if ( config.paranoia ) {
      // Paranoia makes only sense for devices.
      c = new RipAudioDiscCommand!( Device, ParanoiaAudioDiscReader )( config.sourceFile );
    } else {
      c = new RipAudioDiscCommand!( Source, SimpleAudioDiscReader )( config.sourceFile );
    }

    // Simulate?
    if ( config.simulate ) {
      return new SimulateCommand( c );
    }

    return c;
  }
}


class CompoundCommand : AbstractCommand
{
protected:
  Command[] _commands;

public:
  void add( Command c ) {
    _commands ~= c;
    // Compound command registers for signals by added command.
    c.connect( &handleSignal );
    // The KeyValueStore instance of the compound command is used.
    c.setKeyValueStore( keyValueStore() );
  }

  override void setKeyValueStore( KeyValueStore store )
  {
    super.setKeyValueStore( store );

    foreach( command; _commands ) {
      command.setKeyValueStore( store );
    }
  }

  void clear() {
    // Compound command is not responsible for handling signals by commands.
    foreach( command; _commands )
    {
      command.disconnect( &handleSignal );
    }
    _commands.clear();
  }

  bool execute() {
    bool result;

    foreach( i, command; _commands ) {
      logTrace( format( "Execute %s.", command.type() ) );
      result = command.execute();

      if ( result ) { 
        logTrace( format( "Execution of %s was successful.", command.type() ) );
      } else {
        logTrace( format( "Execution of %s failed, abort!", command.type() ) );
        break;
      }
    }

    return result;
  }

  void simulate() {
    if ( _commands.empty() ) {
      writeln( "Be idle ;)" );
      return;
    }

    foreach( command; _commands ) {
      logTrace( format( "Simulate execution of %s.", command.type() ) );
      command.simulate();
      logTrace( format( "End of %s.", command.type() ) );
    }
  }

  mixin introspection.Initial;
}

class PrintCommand : AbstractCommand
{
  File _target;
  string[] _messages;

  // Struct File is created like this:
  //   File f = File( "filename", "openMode" );
  this( File target = stdout )
  {
    _target = target;
  }

  void enqueue( string message, ... )
  {
    _messages ~= message;

    // Add other messages.
    for ( int i = 0; i < _arguments.length; i++ )
    {
      _messages ~= *cast(string *)_argptr;
      _argptr += string.sizeof;
    }
  }

  void enqueue( string[] messages ) {
    _messages ~= messages;
  }

  bool execute() {
    string[] lines = split( _messages.join( "\n" ), "\n" );

    logDebug( format( "Print %d %s.", lines.length, "line".pluralize( lines.length ) ) );
    foreach( i, line; lines ) {
      logTrace( format( "Print line %d.", i + 1 ) );
      _target.writeln( line );
    };

    return true;
  }

  void simulate()
  {
    writeln( "Print message(s)." );
  }

  mixin introspection.Initial;
}

class DetectSourceCommand( T ) : AbstractCommand
{
protected:
  string _path;
  
public:
  this( string path ) 
  {
    _path = path;
  }

  bool execute()
  {
    logDebug( format( "Look for %s %s.", T.stringof.toLower(), _path ) );

    // Find source.
    try { 
      Variant source = T.find( _path );
      keyValueStore().set( T.stringof.toLower(), source ); 
      logDebug( format( "Found %s.", T.stringof.toLower() ) );
      return true;
    } catch ( Exception e ) {
      logError( e.msg ~ "!" );
      return false;
    }
  }

  void simulate()
  {
    writefln( "Detect if %s %s is available.", T.stringof.toLower(), _path );
  }

  mixin introspection.Initial;
}

class DetectSourcesCommand( T ) : AbstractCommand
{
protected:
  string _path;
  
public:
  this( string path = "." ) 
  {
    _path = path;
  }

  bool execute()
  {
    logDebug( format( "Look for %s.", T.stringof.pluralize().toLower() ) );

    try {
      Variant sources = T.findAll( _path );
      keyValueStore().set( T.stringof.pluralize().toLower(), sources ); 
      logDebug( format( "Found %d %s.", sources.length, T.stringof.pluralize( sources.length ).toLower() ) );
      return true;
    } catch ( Exception e ) {
      logError( e.msg ~ "!" );
      return false;
    }
  }

  void simulate()
  {
    writefln( "Detect available %s.", T.stringof.pluralize().toLower() );
  }

  mixin introspection.Initial;
}

class ListSourcesCommand( T ) : CompoundCommand
{
private:
  string _path;

public:
  this( string path = "." )
  {
    _path = path;

    add( new DetectSourcesCommand!( T )( _path ) );
  }

  override bool execute()
  {
    // Look for sources.
    if ( ! super.execute() ) {
      return false;
    }

    // Fetch sources.
    Variant variant = keyValueStore().get( T.stringof.pluralize().toLower() );
    T[] sources = variant.get!( T[] )();

    // Print.
    logDebug( "Print result." );

    if ( sources.length ) {
      writeln( sourcesToString( sources, false ) );
    } else {
      writefln( "No %s found!", T.stringof.pluralize().toLower() );
    }

    return true;
  }

  override void simulate()
  {
    super.simulate();

    writefln( "List available %s.", T.stringof.pluralize().toLower() );
  }

  mixin introspection.Override;
}

class ExploreSourceCommand( T ) : CompoundCommand
{
protected:
  string _path;
  
public:
  this( string path ) 
  {
    _path = path;

    add( new DetectSourceCommand!( T )( _path ) );
  }

  override bool execute()
  {
    // Look for source.
    if ( ! super.execute() ) {
      return false;
    }

    // Fetch source.
    Variant variant = keyValueStore().get( T.stringof.toLower() );
    T source = variant.get!( T );

    logDebug( "Print source description." );
    writeln( sourcesToString( [ source ] ) );

    // Look for audio disc (using SimpleAudioDiscReader).
    logDebug( format( "Looking for audio disc in %s.", source.path() ) );

    // Create reader.
    SimpleAudioDiscReader reader = new SimpleAudioDiscReader( source );
    // Subscribe for signals emitted by reader.
    reader.connect( &handleSignal );

    // Disc?
    try {
      if ( reader.disc() is null ) {
        writeln( "No audio disc found!" );
      } else {
        logDebug( "Print disc layout." );
        writeln();
        writeln( discToString( reader.disc() ) );
      }
    } catch ( Exception e ) {
      logError( e.msg ~ "!" );
      return false;
    }

    return true;
  }

  override void simulate()
  {
    super.simulate();

    writefln( "Explore %s %s.", T.stringof.pluralize().toLower(), _path );
  }

  mixin introspection.Override;
}

class RipAudioDiscCommand( S, T ) : CompoundCommand
{
protected:
  string _path;
  
public:
  this( string path ) 
  {
    _path = path;

    add( new DetectSourceCommand!( S )( _path ) );
  }

  override bool execute()
  {
    // Look for sources.
    if ( ! super.execute() ) {
      return false;
    }

    // Extract source.
    Variant v = keyValueStore().get( S.stringof.toLower() );
    S source = v.get!( S )();

    logDebug( "Print source description." );
    writeln( sourcesToString( [ source ] ) );

    // Look for audio disc (using reader of type T).
    logDebug( format( "Looking for audio disc in %s.", source.path() ) );

    // Create and configure reader.
    T reader = new T();
    reader.setSource( source );
    // Subscribe for signals emitted by reader.
    reader.connect( &handleSignal );

    // Disc?
    try {
      if ( reader.disc() is null ) {
        writeln( "No audio disc found!" );
        return false;
      } else {
        logDebug( "Print disc layout." );
        writeln();
        writeln( discToString( reader.disc() ) );
      }
    } catch ( Exception e ) {
      logError( e.msg ~ "!" );
      return false;
    }

    // TODO: Rip disc!

    return true;
  }

  override void simulate()
  {
    super.simulate();

    writefln( "Rip audio disc from %s using %s.", S.stringof.toLower(), T.stringof );
  }

  mixin introspection.Override;
}

class SimulateCommand : AbstractCommand
{
  Command _command;

  this( Command command )
  {
    _command = command;
    _command.connect( &handleSignal );
  }

  bool execute()
  {
    if ( _command !is null ) {
      logDebug( format( "Simulate execution of %s.", _command.type() ) );
      _command.simulate();
      logDebug( format( "End of %s.", _command.type() ) );
    } else {
      // Shouldn't be reached, normally.
      writeln( "Be idle ;)" );
    }

    return true;
  }

  void simulate()
  {
    // Nothing.
  }

  mixin introspection.Initial;
}

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


module commands;

import std.array;
import std.conv;
import std.file;
import std.signals;
import std.stdio;
import std.string;
import std.variant;

import c.cdio.logging;
import c.cdio.types;

static import introspection;
import log;
import media;
import parsers;
import readers.base;
import readers.jobs;
import readers.paranoia;
import readers.simple;
import sources.base;
import sources.utils;
import utils;

import core.vararg;

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
  void connect( void delegate( string, LogLevel, string, bool, bool ) signalHandler );
  void disconnect( void delegate( string, LogLevel, string, bool, bool ) signalHandler );
  void emit( string emitter, LogLevel level, string message, bool lineBreak, bool prefix );
  final void handleSignal( string emitter, LogLevel level, string message, bool lineBreak, bool prefix ) 
  {
    emit( emitter, level, message, lineBreak, prefix );
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
  Command build( Config config );
}

class DefaultCommandFactory : CommandFactory
{
  Command build( Config config )
  {
    // Help requested?
    if ( config.help ) {
      PrintCommand command = new PrintCommand();
      command.enqueue( config.parser.usage );
      return command;
    }
    
    // Used for composing.
    CompoundCommand c = new CompoundCommand();

    // List sources?
    if ( config.list ) {
      // Explore given source.
      if ( config.sourceFile.length ) {
        c.add( new DetectSourceCommand!( Source!CdIo_t )( config.sourceFile ) );
        c.add( new ExploreSourceCommand!( Source!CdIo_t )() );
        return c;
      }
      // List images in dir.
      if ( config.sourceDirectory.length ) {
        c.add( new DetectSourcesCommand!Image( config.sourceDirectory ) );
        c.add( new ListSourcesCommand!Image() );
        return c;
      }
      // List devices.
      c.add( new DetectSourcesCommand!Device() );
      c.add( new ListSourcesCommand!Device() );
      return c;
    }

    // Rip disc.
    if ( config.paranoia ) {
      // Paranoia makes only sense for devices.
      c.add( new DetectSourceCommand!( Device )( config.sourceFile ) );
      c.add( new RipAudioDiscCommand!( Device, ParanoiaAudioDiscReader )( config ) );
    } else {
      c.add( new DetectSourceCommand!( Source!CdIo_t )( config.sourceFile ) );
      c.add( new RipAudioDiscCommand!( Source!CdIo_t, SimpleAudioDiscReader )( config ) );
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
  void add( Command c )
  {
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

  void clear()
  {
    // Compound command is not responsible for handling signals by commands.
    foreach( command; _commands )
    {
      command.disconnect( &handleSignal );
    }
    _commands.clear();
  }

  bool execute()
  {
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

  void simulate()
  {
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

  ref PrintCommand enqueue( string[] messages... )
  {
    _messages ~= messages;

    return this;
  }

  bool execute()
  {
    string[] lines = split( _messages.join( "\n" ), "\n" );

    logDebug( format( "Print %d %s.", lines.length, "line".pluralize( lines.length ) ) );
    foreach( i, line; lines ) {
      logTrace( format( "Print line %d.", i + 1 ) );
      _target.writeln( line );
    }

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
      if ( source.get!( T )() is null ) {
        logError( format( "%s %s not found!", T.stringof, _path ) );
        return false;
      }
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

class ListSourcesCommand( T ) : AbstractCommand
{
public:
  bool execute()
  {
    // Fetch sources.
    T[] sources;
    try {
      Variant variant = keyValueStore().get( T.stringof.pluralize().toLower() );
      sources = variant.get!( T[] )();
    } catch ( core.exception.RangeError ) {
    }

    // Print.
    logDebug( "Print result." );

    if ( sources.length ) {
      writeln( sourcesToString( sources, false ) );
    } else {
      writefln( "No %s found!", T.stringof.pluralize().toLower() );
    }

    return true;
  }

  void simulate()
  {
    writefln( "List available %s.", T.stringof.pluralize().toLower() );
  }

  mixin introspection.Initial;
}

class ExploreSourceCommand( T ) : AbstractCommand
{
public:
  bool execute()
  {
    // Fetch source.
    T source;
    try {
      Variant variant = keyValueStore().get( T.stringof.toLower() );
      source = variant.get!( T );
    } catch ( core.exception.RangeError ) {
    }

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

  void simulate()
  {
    writefln( "Explore %s.", T.stringof.pluralize().toLower() );
  }

  mixin introspection.Initial;
}


class RipAudioDiscCommand( S, T ) : AbstractCommand
{
private:
  AudioDiscReader _reader;
  Config _config;

public:
  this( Config config )
  {
    _config = config;

    // Create reader.
    _reader = new T();
    // Subscribe for signals emitted by reader.
    _reader.connect( &handleSignal );
    // Add jobs to reader.
    foreach( job; config.jobs ) {
      _reader.add( job );
    }
  }

  bool execute()
  {
    // Extract source from keyValueStore.
    S source;
    try {
      Variant variant = keyValueStore().get( S.stringof.toLower() );
      source = variant.get!( S );
    } catch ( core.exception.RangeError ) {
    }

    if ( source is null ) {
      logError( format( "No %s found!", S.stringof.toLower() ) );
      return false;
    }

    // Configure reader.
    _reader.setSource( source );
    _reader.setSpeed( _config.speed );
    _reader.setWriterConfig( _config.writer );

    // Look for audio disc (using reader of type T).
    logDebug( format( "Looking for audio disc in %s.", source.path() ) );

    // Disc?
    if ( _reader.disc() is null ) {
      writeln( "No audio disc found!" );
      return false;
    }

    // Make sure all jobs are satisfiable.
    ReadFromDiscJob[] jobs = _reader.unsatisfiableJobs();
    if ( jobs.length ) {
      logError( format( "Found %d unsatisfiable job(s):", jobs.length ) );
      foreach ( job; jobs ) { logError( job.description() ); }
      return false;
    }

    // Split jobs?
    if ( ! _config.together ) {
      foreach( job; _reader.jobs().dup ) {
        ReadFromDiscJob[] subJobs = job.split( _reader.disc() );
        if ( subJobs.length > 1 ) {
          logDebug( 
              format(
                  "Split job into %d jobs: %s",
                  subJobs.length,
                  job.description()
                )
            );
          _reader.replace( job, subJobs );
        }
      }
    }

    // Process jobs.
    _reader.read();
    return true;
  }

  void simulate()
  {
    writefln( "Rip audio disc from %s using %s.", S.stringof.toLower(), T.stringof );
  }

  mixin introspection.Initial;
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

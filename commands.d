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
import std.signals;
import std.stdio;
import std.string;

static import introspection;
import log;
import parsers;
import sources.base;
import sources.utils;
import utils;



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
    
    // List devices?
    if ( config.list ) {
      return new ListSourcesCommand!Source( config.source );
    }

    CompoundCommand cc = new CompoundCommand();
    cc.add( new PrintCommand() );
    cc.add( new ListSourcesCommand!Source() );
    cc.add( new PrintCommand() );
    if ( config.simulate ) {
      return new SimulateCommand( cc );
    }

    return cc;
  }
}


class CompoundCommand : Command
{
protected:
  Command[] _commands;

public:
  void add( Command c ) {
    _commands ~= c;
    // Compound command registers for signals by added command.
    c.connect( &handleSignal );
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
    }
  }

  mixin Log;
  mixin introspection.Implementation;
}

class PrintCommand : Command
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

  mixin Log;
  mixin introspection.Implementation;
}


class ListSourcesCommand( T ) : Command
{
protected:
  string _path;

  
public:
  this( string path = "" ) 
  {
    _path = path;
  }

  bool execute()
  {
    // Look for sources.
    if ( _path.empty() ) {
      logDebug( format( "Look for %s.", T.stringof.pluralize().toLower() ) );
      T[] sources = T.find();
      logDebug( format( "Found %d %s.", sources.length, T.stringof.pluralize( sources.length ).toLower() ) );
      logDebug( format( "Print %s.", T.stringof.pluralize( sources.length ).toLower() ) );
      if ( ! sources.empty() ) {
        writefln( "%d %s found:", sources.length, T.stringof.pluralize( sources.length ).toLower() );
        writeln( sources.toString() );
      } else {
        writefln( "No %s found!", T.stringof.pluralize().toLower() );
      }

      return true;
    // Look for source.
    } else {
      logDebug( format( "Look for %s %s.", T.stringof.toLower(), _path ) );
      T source = T.find( _path );
      // Success.
      if ( source !is null ) {
        logDebug( format( "Found %s.", T.stringof.toLower() ) );
        logDebug( format( "Print %s.", T.stringof.toLower() ) );
        writeln( [ source ].toString() );;

        return true;
      // Failure.
      } else {
        logError( format( "%s %s not found!", T.stringof, _path ) );

        return false;
      }
    }
  }

  void simulate()
  {
    writefln( "List available %s.", T.stringof.pluralize().toLower() );
  }

  mixin Log;
  mixin introspection.Implementation;
}

class SimulateCommand : Command
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

  mixin Log;
  mixin introspection.Implementation;
}

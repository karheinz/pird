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


module log;

import std.math;
import std.signals;
import std.stdio;
import std.string;

import parsers;


enum LogLevel
{
  ERROR,
  WARN,
  INFO,
  DEBUG,
  TRACE
}


interface Logger
{
  void handleSignal( string emitter, LogLevel logLevel, string message );
  LogLevel logLevel();
  void setLogLevel( LogLevel logLevel );
}


mixin template Log()
{
  void log( LogLevel logLevel, string message )
  {
    emit( this.type(),logLevel, message );
  }

  void logTrace( string message )
  {
    emit( this.type(), LogLevel.TRACE, message );
  }

  void logDebug( string message )
  {
    emit( this.type(), LogLevel.DEBUG, message );
  }

  void logInfo( string message )
  {
    emit( this.type(), LogLevel.INFO, message );
  }

  void logWarn( string message )
  {
    emit( this.type(), LogLevel.WARN, message );
  }

  void logError( string message )
  {
    emit( this.type(), LogLevel.ERROR, message );
  }

  mixin Signal!( string, LogLevel, string );
}


class DefaultLogger : Logger
{
private:
  LogLevel _logLevel;
  File _file;

protected:
  static LogLevel defaultLogLevel = LogLevel.INFO;

  this( File file = stderr ) {
    _file = file;
    _logLevel = defaultLogLevel;
  };

public:
  void handleSignal( string emitter, LogLevel logLevel, string message ) 
  {
    if ( logLevel <= _logLevel ) {
      version( devel ) {
        _file.writefln( "%s %s: %s", logLevel, emitter, message );
      } else {
        _file.writefln( "%s: %s", logLevel, message );
      }
    }
  }

  LogLevel logLevel()
  {
    return _logLevel;
  }

  void setLogLevel( LogLevel logLevel )
  {
    _logLevel = logLevel;
  }
}

interface LoggerFactory
{
  Logger build( Configuration config );
}

class DefaultLoggerFactory : LoggerFactory
{
  Logger build( Configuration config )
  {
    DefaultLogger logger = new DefaultLogger();
    if ( config.verbose ) {
      logger.setLogLevel( cast( LogLevel )( fmin( logger.logLevel() + config.verbose, LogLevel.max ) ) );
    }

    return logger;
  }
}

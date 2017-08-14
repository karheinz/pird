/+
  Copyright (C) 2011-2017 Karsten Heinze <karsten@sidenotes.de>

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

import core.stdc.string;

import std.conv;
import std.math;
import std.signals;
import std.stdio;
import std.string;

import c.cdio.logging;

static import introspection;
import parsers;
import utils;


enum LogLevel
{
    NONE,
    ERROR,
    WARNING,
    INFO,
    DEBUG,
    TRACE
}


interface Logger
{
    void handleSignal( string emitter, LogLevel logLevel, string message, bool lineBreak, bool prefix );
    LogLevel logLevel();
    void setLogLevel( LogLevel logLevel );
}


mixin template Log( )
{
protected:
    void log( LogLevel logLevel, string message, bool lineBreak = true, bool prefix = true )
    {
        emit( this.type(), logLevel, message, lineBreak, prefix );
    }

    void logTrace( string message, bool lineBreak = true, bool prefix = true )
    {
        log( LogLevel.TRACE, message, lineBreak, prefix );
    }

    void logDebug( string message, bool lineBreak = true, bool prefix = true )
    {
        log( LogLevel.DEBUG, message, lineBreak, prefix );
    }

    void logInfo( string message, bool lineBreak = true, bool prefix = true )
    {
        log( LogLevel.INFO, message, lineBreak, prefix );
    }

    void logWarning( string message, bool lineBreak = true, bool prefix = true )
    {
        log( LogLevel.WARNING, message, lineBreak, prefix );
    }

    void logError( string message, bool lineBreak = true, bool prefix = true )
    {
        log( LogLevel.ERROR, message, lineBreak, prefix );
    }

public:
    mixin Signal!( string, LogLevel, string, bool, bool );
}



class CdIoLogGateway : introspection.Interface
{
private:
    this( )
    {
        cdio_log_set_handler( &logCdIoMessage );
        _logLevel = defaultLogLevel;
    }
    // Emit all libcdio messages by default.
    static cdio_log_level_t defaultLogLevel = cdio_log_level_t.CDIO_LOG_DEBUG;
    static CdIoLogGateway   _instance;

    cdio_log_level_t _logLevel;

public:
    // Used as callback of a C function.
    extern ( C ) static void logCdIoMessage( cdio_log_level_t level, const char* message )
    {
        // Throw away log messages with level smaller than default.
        if ( level < defaultLogLevel )
            return;

        LogLevel l;

        final switch ( level )
        {
            case cdio_log_level_t.CDIO_LOG_DEBUG:
                l = LogLevel.DEBUG;
                break;
            case cdio_log_level_t.CDIO_LOG_INFO:
                l = LogLevel.INFO;
                break;
            case cdio_log_level_t.CDIO_LOG_WARN:
                l = LogLevel.WARNING;
                break;
            case cdio_log_level_t.CDIO_LOG_ERROR:
                l = LogLevel.ERROR;
                break;
            case cdio_log_level_t.CDIO_LOG_ASSERT:
                l = LogLevel.ERROR;
                break;
        }

        instance().log( l, to!string( message ) );
    }

    static CdIoLogGateway instance()
    {
        if ( _instance is null )
        {
            _instance = new CdIoLogGateway();
        }

        return _instance;
    }

    string type()
    {
        return "CdIoLib";
    }

    cdio_log_level_t logLevel()
    {
        return _logLevel;
    }

    void setLogLevel( cdio_log_level_t logLevel )
    {
        _logLevel = logLevel;
    }

    mixin Log;
}

class DefaultLogger : Logger
{
private:
    LogLevel _logLevel;
    File     _file;

protected:
    static LogLevel defaultLogLevel = LogLevel.INFO;

    this( File file = stderr ) {
        _file     = file;
        _logLevel = defaultLogLevel;

        // Subscribe for signals emitted by libcdio.
        CdIoLogGateway.instance().connect( &handleSignal );
    };

public:
    void handleSignal( string emitter, LogLevel logLevel, string message, bool lineBreak, bool prefix )
    {
        // Filter messages by CdIo library, which is very verbose by default.
        if ( emitter == "CdIoLib" && ( logLevel + 1 ) > _logLevel )
        {
            return;
        }

        // Filter other messages by log level.
        if ( logLevel > _logLevel )
        {
            return;
        }

        // Write log message.
        version ( devel )
        {
            _file.writef(
                "%s%s%s%s",
                prefix ? to!string( logLevel ) : "",
                prefix ? format( " %s: ", emitter ) : "",
                message,
                lineBreak ? "\n" : ""
                );
        }
        else
        {
            _file.writef(
                "%s%s%s",
                prefix ? format( "%s: ", to!string( logLevel ) ) : "",
                message,
                lineBreak ? "\n" : ""
                );
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
    Logger build( Config config );
}

class DefaultLoggerFactory : LoggerFactory
{
    Logger build( Config config )
    {
        DefaultLogger logger = new DefaultLogger();
        if ( config.verbose )
        {
            logger.setLogLevel( cast( LogLevel )( fmin( logger.logLevel() + config.verbose, LogLevel.max ) ) );
        }
        if ( config.quiet )
        {
            logger.setLogLevel( LogLevel.NONE );
        }

        return logger;
    }
}

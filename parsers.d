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


module parsers;

import std.array;
import std.conv;
import std.file;
import std.getopt;
import std.regex;
import std.stdio;
import std.string;

import readers.jobs;


struct Configuration
{
  Parser.Info parser;
  string sourceFile, sourceDirectory;
  ReadFromDiscJob[] jobs;
  bool help, quiet, list, simulate, paranoia;
  int verbose;
}


interface Parser
{
  struct Info
  {
    string name, usage, error;
  }
  
  static immutable string command = "pird";

  bool parse( string[] args, out Configuration config );
  string usage( string command = Parser.command );
}

final class DefaultCommandLineParser : Parser
{
protected:
  static string _usage = import( this.stringof ~ "Usage.txt" );
  enum Syntax { HELP, LIST, RIP };

  class RangeParser
  {
  private:
    this() {};

  public:
    enum Tokens : string
    {
      CONNECTOR_INCL = r"[.]{2}",
      CONNECTOR_EXCL = r"[.]{3}",
      SEPARATOR = r",",
      TRACK = r"\d+",
      OFFSET_MARKER_L = r"\[",
      OFFSET_MARKER_R = r"\]",
      MINUTE = r"\d+",
      SECOND = r"\d{1,2}",
      FRAME = r"\d{1,3}",
      MS_SEPARATOR = r":",
      SF_SEPARATOR = r"\."
    }

    enum Patterns : string
    {
      CONNECTORS = 
        "(" ~ Tokens.CONNECTOR_INCL ~ ")|(" ~ Tokens.CONNECTOR_EXCL ~ ")",
      LABEL = 
        "(?P<t>" ~ Tokens.TRACK ~ ")" ~
        "(" ~
          Tokens.OFFSET_MARKER_L ~
          "(?P<m>" ~ Tokens.MINUTE ~ ")" ~
          Tokens.MS_SEPARATOR ~
          "(?P<s>" ~ Tokens.SECOND ~ ")" ~
          Tokens.SF_SEPARATOR ~
          "(?P<f>" ~ Tokens.FRAME ~ ")" ~
          Tokens.OFFSET_MARKER_R ~ 
        ")?",
      RANGE_FULL = 
        "(?P<from>" ~ LABEL ~ ")" ~
        "(?P<connector>" ~ CONNECTORS ~ ")" ~
        "(?P<to>" ~ LABEL ~ ")",
      RANGE_FROM =
        "(?P<from>" ~ LABEL ~ ")" ~
        "(?P<connector>" ~ Tokens.CONNECTOR_INCL ~ ")",
      RANGE_TO =
        "(?P<connector>" ~ CONNECTORS ~ ")" ~
        "(?P<to>" ~ LABEL ~ ")",
      RANGE = "(" ~ RANGE_FULL ~ ")|(" ~ RANGE_FROM ~ ")|(" ~ RANGE_TO ~ ")"
    }


    static ReadFromDiscJob[] parse( string r )
    {
      ReadFromDiscJob[] result;

      string[] ranges = split( r, to!string( Tokens.SEPARATOR ) );
      foreach ( range; ranges ) {
        auto c = match( range, "^(" ~ Patterns.RANGE ~ ")$" ).captures();

        if ( c.empty() ) {
          throw new Exception( "Invalid range description" );
        } else {
          c = match( range, "^(" ~ Patterns.RANGE_TO ~ ")$" ).captures();
          if ( ! c.empty() ) {
            writefln( "RANGE_TO: %s", c[ "to" ] );
            writeln( "Connector " ~ c[ "connector" ] );
            c = match( c[ "to" ], "^" ~ Patterns.LABEL ~ "$" ).captures();
            string strack = to!string( c[ "t" ] );
            int track = std.conv.parse!int( strack );
            writefln( "Track is %d", track );
            writeln( "m " ~ c[ "m" ] );
            writeln( "s " ~ c[ "s" ] );
            writeln( "f " ~ c[ "f" ] );
            continue;
          }
          c = match( range, "^(" ~ Patterns.RANGE_FROM ~ ")$" ).captures();
          if ( ! c.empty() ) {
            writefln( "RANGE_FROM: %s", range );
            writeln( "Connector " ~ c[ "connector" ] );
            c = match( c[ "from" ], "^" ~ Patterns.LABEL ~ "$" ).captures();
            string strack = to!string( c[ "t" ] );
            int track = std.conv.parse!int( strack );
            writefln( "Track is %d", track );
            writeln( "m " ~ c[ "m" ] );
            writeln( "s " ~ c[ "s" ] );
            writeln( "f " ~ c[ "f" ] );
            continue;
          } 
          c = match( range, "^(" ~ Patterns.RANGE_FULL ~ ")$" ).captures();
          if ( ! c.empty() ) {
            writefln( "RANGE_FULL: %s", range );
            writeln( "Connector " ~ c[ "connector" ] );
            auto c1 = match( c[ "from" ], "^" ~ Patterns.LABEL ~ "$" ).captures();
            string strack = to!string( c1[ "t" ] );
            int track = std.conv.parse!int( strack );
            writefln( "Track is %d", track );
            writeln( "m " ~ c1[ "m" ] );
            writeln( "s " ~ c1[ "s" ] );
            writeln( "f " ~ c1[ "f" ] );
            c1 = match( c[ "to" ], "^" ~ Patterns.LABEL ~ "$" ).captures();
            strack = to!string( c1[ "t" ] );
            track = std.conv.parse!int( strack );
            writefln( "Track is %d", track );
            writeln( "m " ~ c1[ "m" ] );
            writeln( "s " ~ c1[ "s" ] );
            writeln( "f " ~ c1[ "f" ] );
            continue;
          } 
        }
      }

      return result;
    }
  }

  bool parse( Syntax syntax, string[] args, out Configuration config, out string error ) {
    try {
      // Apply syntax to command line.
      final switch( syntax )
      {
        case Syntax.HELP:
          version( devel ) {
            getopt(
              args,
              std.getopt.config.caseSensitive,
              std.getopt.config.bundling,
              "help|h", &config.help,
              "verbose+|v+", &config.verbose
            );
          } else {
            getopt(
              args,
              std.getopt.config.caseSensitive,
              std.getopt.config.bundling,
              "help|h", &config.help
            );

          }

          if ( !config.help || args.length > 1 ) {
            throw new Exception( "Syntax error" );
          }

          // Parsing was successful.
          return true;
        case Syntax.LIST:
          version( devel ) {
            getopt(
              args,
              std.getopt.config.caseSensitive,
              std.getopt.config.bundling,
              "list|l", &config.list,
              "verbose+|v+", &config.verbose
            );
          } else {
            getopt(
              args,
              std.getopt.config.caseSensitive,
              std.getopt.config.bundling,
              "list|l", &config.list
            );
          }

          if ( !config.list || args.length > 2 ) {
            throw new Exception( "Syntax error" );
          }

          // Store directory/source to list if passed.
          if ( args.length == 2 ) {
            // Source does not exist.
            if ( ! exists( args[ 1 ] ) ) {
              config.sourceFile = args[ 1 ]; 
            // Source exists.
            } else {
              if ( isDir( args[ 1 ] ) ) {
                config.sourceDirectory = args[ 1 ];
              } else {
                config.sourceFile = args[ 1 ];
              }
            }
          }

          // Parsing was successful.
          return true;
        // TODO: Build ReadFromDiscJobs!
        case Syntax.RIP:
          getopt(
            args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "verbose+|v+", &config.verbose,
            "quiet|q", &config.quiet,
            "simulate|s", &config.simulate,
            "paranoia|p", &config.paranoia
          );


          // Source is second arg left.
          switch ( args.length )
          {
            case 1:
              throw new Exception( "Missing source" );
            case 2:
              config.sourceFile = args[ 1 ];
              break;
            case 3:
              config.sourceFile = args[ 2 ];
              config.jobs = RangeParser.parse( args[ 1 ] );
              break;
            default:
              throw new Exception( "Syntax error" );
          }

          // Either verbose or quiet!
          if ( config.verbose && config.quiet ) {
            throw new Exception( "Switches -v and -q are mutual exclusiv" );
          }

          // Parsing was successful.
          return true;
      }
    } catch ( Exception e ) {
      clear( config );
      error = e.msg;
      return false;
    }       
  }
    

public:
  bool parse( string[] args, out Configuration config )
  {
    // Build info about parser.
    Parser.Info info;
    info.name = this.stringof;
    info.usage = usage( args[ 0 ] );

    // For parse errors.
    string error;

    // Parse command line till first syntax matches.
    for( Syntax syntax = Syntax.min; syntax <= Syntax.max; syntax++ ) {
      if ( parse( syntax, args, config, error ) ) {
        config.parser = info;
        return true;
      }
    }

    // No syntax matched!
    info.error = error ~ "!";
    config.parser = info;
    return false;
  }

  string usage( string command )
  {
    // Replace command place holders and last linebreak.
    return replace( _usage, "%s", command )[ 0 .. ( $ - 1 ) ];
  }
}

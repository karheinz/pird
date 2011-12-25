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

import std.array;
import std.conv;
import std.file;
import std.getopt;
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
            default:
              throw new Exception( "Multiple sources" );
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

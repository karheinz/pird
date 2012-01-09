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

import c.cdio.types;

import media;
import readers.jobs;
import utils;


struct Configuration
{
  Parser.Info parser;
  string sourceFile, sourceDirectory;
  ReadFromDiscJob[] jobs;
  bool help, quiet, list, simulate, paranoia, stdout, trackwise;
  int verbose;
}
unittest
{
  Configuration config;
  config.parser = Parser.Info();
  config.parser.generator = new DefaultFilenameGenerator();

  Configuration copy = config;
  assert( copy.parser.generator !is null );
  config.parser.generator = null;
  assert( copy.parser.generator is null );
}


interface Parser
{
  struct Info
  {
    string name, usage, error;
    FilenameGenerator generator;
  }
  
  static immutable string command = "pird";

  bool parse( string[] args, out Configuration config );
  string usage( string command = Parser.command );
}

interface FilenameGenerator
{
  final static string generate( File file )
  {
    if ( file is stdout ) { return "stdout"; }
    if ( file is stderr ) { return "stderr"; }

    throw new Exception( "Only stdout and stderr are allowed" );
  }
  string generate();
  string generate( int track );
  string generate( Labels label, int track, lsn_t sector );
  string generate( int fromTrack, lsn_t fromSector, int toTrack, lsn_t toSector );
  string generate( lsn_t fromSector, lsn_t toSector );
}

final class DefaultCommandLineParser : Parser
{
public:
  this()
  {
    _generator = new DefaultFilenameGenerator();
  }

  this( FilenameGenerator generator )
  {
    _generator = generator;
  }

  FilenameGenerator filenameGenerator()
  {
    return _generator;
  }

  void setFilenameGenerator( FilenameGenerator generator )
  {
    _generator = generator;
  }

  bool parse( string[] args, out Configuration config )
  {
    // Build info about parser.
    Parser.Info info;
    info.name = typeof( this ).stringof;
    info.usage = usage( args[ 0 ] );
    info.generator = _generator;

    // Add to parser info to config.
    config.parser = info;

    // For parse errors.
    string error;

    // Parse command line till first syntax matches.
    for( Syntax syntax = Syntax.min; syntax <= Syntax.max; syntax++ ) {
      if ( parse( syntax, args, config, error ) ) {
        return true;
      }

      // Failure! Struct config got cleared, so add info again.
      config.parser = info;
    }

    // No syntax matched!
    config.parser.error = error ~ "!";
    return false;
  }

  string usage( string command )
  {
    // Replace command place holders and last linebreak.
    return replace( _usage, "%s", command )[ 0 .. ( $ - 1 ) ];
  }

private:
  static string _usage = import( this.stringof ~ "Usage.txt" );
  enum Syntax { HELP, LIST, RIP };
  FilenameGenerator _generator;

  class JobParser
  {
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
      TRACK = "(?P<t>" ~ Tokens.TRACK ~ ")",
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


    static ReadFromDiscJob[] parse( string input, Configuration config )
    {
      ReadFromDiscJob job;
      ReadFromDiscJob[] jobs;

      // Read full disc?
      if ( input.empty() ) {
        job = new ReadFromAudioDiscJob();

        // Stdout is target?
        if ( config.stdout ) {
          job.target.file = config.parser.generator.generate( stdout );
          job.target.writerClass = "writers.wav.StdoutWriter";
        // Write to file.
        } else {
          job.target.file = config.parser.generator.generate();
          job.target.writerClass = "writers.wav.FileWriter";
        }

        jobs ~= job;
        return jobs;
      }

      
      // Extract job descriptions.
      string[] descs = split( input, to!string( Tokens.SEPARATOR ) );
      foreach ( desc; descs ) {
        auto c = match( desc, "^((" ~ Patterns.RANGE ~ ")|(" ~ Patterns.TRACK ~ "))$" ).captures();

        if ( c.empty() ) {
          throw new Exception( "Invalid track/range description" );
        } else {
          // Singe track?
          c = match( desc, "^" ~ Patterns.TRACK ~ "$" ).captures();
          if ( ! c.empty() ) {
            string st = to!string( c[ "t" ] );
            int t = std.conv.parse!int( st );

            job = new ReadFromAudioDiscJob( t );
            // Stdout is target?
            if ( config.stdout ) {
              job.target.file = config.parser.generator.generate( stdout );
              job.target.writerClass = "writers.wav.StdoutWriter";
            // Write to file.
            } else {
              job.target.file = config.parser.generator.generate( t );
              job.target.writerClass = "writers.wav.FileWriter";
            }
            jobs ~= job;
            continue;
          }
          // From BEGIN to label?
          c = match( desc, "^(" ~ Patterns.RANGE_TO ~ ")$" ).captures();
          if ( ! c.empty() ) {
            // Connector type?
            auto c1 = match(
                c[ "connector" ], "^" ~ Tokens.CONNECTOR_EXCL ~ "$"
              ).captures();
            // Get track and offset.
            auto c2 = match(
                c[ "to" ], "^" ~ Patterns.LABEL ~ "$"
              ).captures();

            string st = to!string( c2[ "t" ] );
            int t = std.conv.parse!int( st );
            lsn_t o = -1;
            
            // Offset?
            if ( ! c2[ "m" ].empty() ) {
              string sm = to!string( c2[ "m" ] );
              ubyte m = std.conv.parse!ubyte( sm );
              string ss = to!string( c2[ "s" ] );
              ubyte s = std.conv.parse!ubyte( ss );
              string sf = to!string( c2[ "f" ] );
              ubyte f = std.conv.parse!ubyte( sf );

              o = msf_to_sectors( msf_t( m, s, f ) );
            }
            // Exclude label?
            if ( ! c1.empty() ) {
              // Rip up to track t - 1?
              if ( o <= 0 ) {
                t--;
                o = -1;
              } else {
                o--;
              }
            }

            job = new ReadFromAudioDiscJob( Labels.DISC_BEGIN, t, o );
            // Stdout is target?
            if ( config.stdout ) {
              job.target.file = config.parser.generator.generate( stdout );
              job.target.writerClass = "writers.wav.StdoutWriter";
            // Write to file.
            } else {
              job.target.file = config.parser.generator.generate( Labels.DISC_BEGIN, t, o );
              job.target.writerClass = "writers.wav.FileWriter";
            }
            jobs ~= job;
            continue;
          }
          // From label to END?
          c = match( desc, "^(" ~ Patterns.RANGE_FROM ~ ")$" ).captures();
          if ( ! c.empty() ) {
            // Get track and offset.
            auto c1 = match( c[ "from" ], "^" ~ Patterns.LABEL ~ "$").captures();

            string st = to!string( c1[ "t" ] );
            int t = std.conv.parse!int( st );
            lsn_t o;
            
            // Offset?
            if ( ! c1[ "m" ].empty() ) {
              string sm = to!string( c1[ "m" ] );
              ubyte m = std.conv.parse!ubyte( sm );
              string ss = to!string( c1[ "s" ] );
              ubyte s = std.conv.parse!ubyte( ss );
              string sf = to!string( c1[ "f" ] );
              ubyte f = std.conv.parse!ubyte( sf );

              o = msf_to_sectors( msf_t( m, s, f ) );
            }

            job = new ReadFromAudioDiscJob( Labels.DISC_END, t, o );
            // Stdout is target?
            if ( config.stdout ) {
              job.target.file = config.parser.generator.generate( stdout );
              job.target.writerClass = "writers.wav.StdoutWriter";
            // Write to file.
            } else {
              job.target.file = config.parser.generator.generate( Labels.DISC_END, t, o );
              job.target.writerClass = "writers.wav.FileWriter";
            }
            jobs ~= job;
            continue;
          }
          // From label to label?
          c = match( desc, "^(" ~ Patterns.RANGE_FULL ~ ")$" ).captures();
          if ( ! c.empty() ) {
            // Connector type?
            auto c1 = match(
                c[ "connector" ], "^" ~ Tokens.CONNECTOR_EXCL ~ "$"
              ).captures();
            // Get tracks and offsets.
            auto c2 = match(
                c[ "from" ], "^" ~ Patterns.LABEL ~ "$"
              ).captures();
            auto c3 = match(
                c[ "to" ], "^" ~ Patterns.LABEL ~ "$"
              ).captures();

            string st1 = to!string( c2[ "t" ] );
            int t1 = std.conv.parse!int( st1 );
            lsn_t o1;
            
            // Offset?
            if ( ! c2[ "m" ].empty() ) {
              string sm1 = to!string( c2[ "m" ] );
              ubyte m1 = std.conv.parse!ubyte( sm1 );
              string ss1 = to!string( c2[ "s" ] );
              ubyte s1 = std.conv.parse!ubyte( ss1 );
              string sf1 = to!string( c2[ "f" ] );
              ubyte f1 = std.conv.parse!ubyte( sf1 );

              o1 = msf_to_sectors( msf_t( m1, s1, f1 ) );
            }
            string st2 = to!string( c3[ "t" ] );
            int t2 = std.conv.parse!int( st2 );
            lsn_t o2 = -1;
            
            // Offset?
            if ( ! c3[ "m" ].empty() ) {
              string sm2 = to!string( c3[ "m" ] );
              ubyte m2 = std.conv.parse!ubyte( sm2 );
              string ss2 = to!string( c3[ "s" ] );
              ubyte s2 = std.conv.parse!ubyte( ss2 );
              string sf2 = to!string( c3[ "f" ] );
              ubyte f2 = std.conv.parse!ubyte( sf2 );

              o2 = msf_to_sectors( msf_t( m2, s2, f2 ) );
            }

            // Exclude label?
            if ( ! c1.empty() ) {
              // Rip up to track t - 1?
              if ( o2 <= 0 ) {
                t2--;
                o2 = -1;
              } else {
                o2--;
              }
            }
            job = new ReadFromAudioDiscJob( t1, o1, t2, o2 );
            // Stdout is target?
            if ( config.stdout ) {
              job.target.file = config.parser.generator.generate( stdout );
              job.target.writerClass = "writers.wav.StdoutWriter";
            // Write to file.
            } else {
              job.target.file = config.parser.generator.generate( t1, o1, t2, o2 );
              job.target.writerClass = "writers.wav.FileWriter";
            }
            jobs ~= job;
            continue;
          } 
        }
      }

      // Return jobs.
      return jobs;
    }
  }

  bool parse( Syntax syntax, string[] args, ref Configuration config, out string error ) {
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

          // Drop command.
          args.popFront();

          if ( !config.help || args.length ) {
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

          // Drop command.
          args.popFront();

          if ( !config.list || args.length > 1 ) {
            throw new Exception( "Syntax error" );
          }

          // Store directory/source to list if passed.
          if ( args.length == 1 ) {
            // Source does not exist.
            if ( ! exists( args[ 0 ] ) ) {
              config.sourceFile = args[ 0 ]; 
            // Source exists.
            } else {
              if ( isDir( args[ 0 ] ) ) {
                config.sourceDirectory = args[ 0 ];
              } else {
                config.sourceFile = args[ 0 ];
              }
            }
          }

          // Parsing was successful.
          return true;
        case Syntax.RIP:
          getopt(
            args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            std.getopt.config.passThrough,
            "verbose+|v+", &config.verbose,
            "quiet|q", &config.quiet,
            "simulate|s", &config.simulate,
            "paranoia|p", &config.paranoia,
            "trackwise|t", &config.trackwise
          );

          // Drop command.
          args.popFront();

          // Check for target stdout.
          if ( args.length && args.back() == "-" ) {
            args.popBack();
            config.stdout = true;
          }

          // Unset trackwise if target is stdout!
          if ( config.stdout ) { config.trackwise = false; }


          // Parse job descriptions and source.
          switch ( args.length )
          {
            case 0:
              throw new Exception( "Missing source" );
            case 1:
              config.sourceFile = args[ 0 ];
              config.jobs = JobParser.parse( "", config );
              break;
            case 2:
              config.sourceFile = args[ 1 ];
              config.jobs = JobParser.parse( args[ 0 ], config );
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
}

class DefaultFilenameGenerator : FilenameGenerator
{
 
  // FIXME: Return right file extension.
  string generate()
  {
    return "disc.wav";
  }

  string generate( int track )
  {
    return format( "track_%02d.wav", track );
  }

  string generate( Labels label, int track, lsn_t sector )
  {
    switch ( label ) {
      case Labels.DISC_BEGIN:
        return format( "range_..%02d%s.wav", track, msfToString( sectors_to_msf( sector ) ) );
      case Labels.DISC_END:
        return format( "range_%02d%s...wav", track, msfToString( sectors_to_msf( sector ) ) );
      case Labels.TRACK_BEGIN:
        return format( "track_..%02d%s.wav", track, msfToString( sectors_to_msf( sector ) ) );
      case Labels.TRACK_END:
        return format( "track_%02d%s...wav", track, msfToString( sectors_to_msf( sector ) ) );
      default:
        throw new Exception( format( "Unsupported label %s", to!string( label ) ) );
    }
  }

  string generate( int fromTrack, lsn_t fromSector, int toTrack, lsn_t toSector )
  {
    return format(
        "range_%02d%s..%02d%s.wav",
        fromTrack,
        msfToString( sectors_to_msf( fromSector ) ),
        toTrack,
        msfToString( sectors_to_msf( toSector ) )
      );
  }

  string generate( lsn_t fromSector, lsn_t toSector )
  {
    return format(
        "range_%s..%s.wav",
        msfToString( sectors_to_msf( fromSector ) ),
        msfToString( sectors_to_msf( toSector ) )
      );
  }
}

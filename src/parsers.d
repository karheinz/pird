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


module parsers;

import std.array;
import std.conv;
import std.file;
import std.getopt;
import std.regex;
import std.stdio;
import std.string;

import c.cdio.types;

import eponyms;
import media;
import readers.jobs;
import utils;
import writers.base;


struct Config
{
    Parser.Info       parser;
    string            sourceFile, sourceDirectory;
    Writer.Config     writer;
    ReadFromDiscJob[] jobs;
    bool              help, quiet, list, simulate, paranoia,
                      stdout, together, swap, accurate, calibrate;
    int               verbose, offset;
    ubyte             speed;
}


interface Parser
{
    enum AudioFormat { WAV, PCM };

    struct Info
    {
        string name, usage, error;
    }

    static immutable string command = "pird";

    bool parse( string[] args, out Config config );
    string usage( string command = Parser.command );
}


final class DefaultCommandLineParser : Parser
{
public:
    this( )
    {
        _eponym = new DefaultEponym();
    }

    Eponym eponym()
    {
        return _eponym;
    }

    void setEponym( Eponym eponym )
    {
        _eponym = eponym;
    }

    bool parse( string[] args, out Config config )
    {
        // Build info about parser.
        Parser.Info info;
        info.name  = typeof( this ).stringof;
        info.usage = usage( args[ 0 ] );

        // For parse errors.
        string error;

        // Parse command line till first syntax matches.
        for ( Syntax syntax = Syntax.min; syntax <= Syntax.max; syntax++ )
        {
            if ( parse( syntax, args, config, error ) )
            {
                // Add parser info to config.
                config.parser = info;
                return true;
            }
        }

        // Add parser info to config.
        config.parser = info;

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
    static string _usage = import ( this.stringof ~ "Usage.txt" );
    enum Syntax { HELP, LIST, RIP };
    Eponym _eponym;

    AudioFormat extractAudioFormat( string description )
    {
        bool        success;
        AudioFormat f;

        for ( f = AudioFormat.min; f <= AudioFormat.max; f++ )
        {
            if ( to!string( f ) == description.toUpper() )
            {
                success = true;
                break;
            }
        }

        if ( !success )
        {
            throw new Exception( format( "Audio format %s is unknown", description.toUpper() ) );
        }

        return f;
    }

    class JobParser
    {
        enum Token : string
        {
            CONNECTOR_INCL  = r"[.]{2}",
            CONNECTOR_EXCL  = r"[.]{3}",
            SEPARATOR       = r",",
            TRACK           = r"\d+",
            OFFSET_MARKER_L = r"\[",
            OFFSET_MARKER_R = r"\]",
            MINUTE          = r"\d+",
            SECOND          = r"\d{1,2}",
            FRAME           = r"\d{1,3}",
            MS_SEPARATOR    = r":",
            SF_SEPARATOR    = r"\."
        }

        enum Pattern : string
        {
            CONNECTORS =
                "(" ~ Token.CONNECTOR_INCL ~ ")|(" ~ Token.CONNECTOR_EXCL ~ ")",
            LABEL =
                "(?P<t>" ~ Token.TRACK ~ ")" ~
                "(" ~
                Token.OFFSET_MARKER_L ~
                "(?P<m>" ~ Token.MINUTE ~ ")" ~
                Token.MS_SEPARATOR ~
                "(?P<s>" ~ Token.SECOND ~ ")" ~
                Token.SF_SEPARATOR ~
                "(?P<f>" ~ Token.FRAME ~ ")" ~
                Token.OFFSET_MARKER_R ~
                ")?",
            TRACK      = "(?P<t>" ~ Token.TRACK ~ ")",
            RANGE_FULL =
                "(?P<from>" ~ LABEL ~ ")" ~
                "(?P<connector>" ~ CONNECTORS ~ ")" ~
                "(?P<to>" ~ LABEL ~ ")",
            RANGE_FROM =
                "(?P<from>" ~ LABEL ~ ")" ~
                "(?P<connector>" ~ Token.CONNECTOR_INCL ~ ")",
            RANGE_TO =
                "(?P<connector>" ~ CONNECTORS ~ ")" ~
                "(?P<to>" ~ LABEL ~ ")",
            RANGE = "(" ~ RANGE_FULL ~ ")|(" ~ RANGE_FROM ~ ")|(" ~ RANGE_TO ~ ")"
        }


        static ReadFromDiscJob[] parse( string input = "" )
        {
            // Read full disc?
            if ( input.empty() )
            {
                return [ new ReadFromAudioDiscJob() ];
            }


            // Extract job descriptions.
            ReadFromDiscJob[] jobs;

            string[] descs = split( input, cast( string )( Token.SEPARATOR ) );
            foreach ( desc; descs )
            {
                auto c = match( desc, "^((" ~ Pattern.RANGE ~ ")|(" ~ Pattern.TRACK ~ "))$" ).captures();

                if ( c.empty() )
                {
                    throw new Exception( "Invalid track/range description" );
                }
                else
                {
                    // Singe track?
                    c = match( desc, "^" ~ Pattern.TRACK ~ "$" ).captures();
                    if ( !c.empty() )
                    {
                        string st = to!string( c[ "t" ] );
                        ubyte   t  = std.conv.parse!ubyte( st );

                        jobs ~= new ReadFromAudioDiscJob( t );
                        continue;
                    }
                    // From BEGIN to label?
                    c = match( desc, "^(" ~ Pattern.RANGE_TO ~ ")$" ).captures();
                    if ( !c.empty() )
                    {
                        // Connector type?
                        auto c1 = match(
                            c[ "connector" ], "^" ~ Token.CONNECTOR_EXCL ~ "$"
                            ).captures();
                        // Get track and offset.
                        auto c2 = match(
                            c[ "to" ], "^" ~ Pattern.LABEL ~ "$"
                            ).captures();

                        string st = to!string( c2[ "t" ] );
                        ubyte  t  = std.conv.parse!ubyte ( st );
                        lsn_t  o  = -1;

                        // Offset?
                        if ( !c2[ "m" ].empty() )
                        {
                            string sm = to!string( c2[ "m" ] );
                            ubyte  m  = std.conv.parse!ubyte ( sm );
                            string ss = to!string( c2[ "s" ] );
                            ubyte  s  = std.conv.parse!ubyte ( ss );
                            string sf = to!string( c2[ "f" ] );
                            ubyte  f  = std.conv.parse!ubyte ( sf );

                            o = msfToSectors( msf_t( m, s, f ) );
                        }
                        // Exclude label?
                        if ( !c1.empty() )
                        {
                            // Rip up to track t - 1?
                            if ( o <= 0 )
                            {
                                t--;
                                o = -1;
                            }
                            else
                            {
                                o--;
                            }
                        }

                        jobs ~= new ReadFromAudioDiscJob( Label.DISC_BEGIN, t, o );
                        continue;
                    }
                    // From label to END?
                    c = match( desc, "^(" ~ Pattern.RANGE_FROM ~ ")$" ).captures();
                    if ( !c.empty() )
                    {
                        // Get track and offset.
                        auto c1 = match( c[ "from" ], "^" ~ Pattern.LABEL ~ "$" ).captures();

                        string st = to!string( c1[ "t" ] );
                        ubyte  t  = std.conv.parse!ubyte( st );
                        lsn_t  o;

                        // Offset?
                        if ( !c1[ "m" ].empty() )
                        {
                            string sm = to!string( c1[ "m" ] );
                            ubyte  m  = std.conv.parse!ubyte ( sm );
                            string ss = to!string( c1[ "s" ] );
                            ubyte  s  = std.conv.parse!ubyte ( ss );
                            string sf = to!string( c1[ "f" ] );
                            ubyte  f  = std.conv.parse!ubyte ( sf );

                            o = msfToSectors( msf_t( m, s, f ) );
                        }

                        jobs ~= new ReadFromAudioDiscJob( Label.DISC_END, t, o );
                        continue;
                    }
                    // From label to label?
                    c = match( desc, "^(" ~ Pattern.RANGE_FULL ~ ")$" ).captures();
                    if ( !c.empty() )
                    {
                        // Connector type?
                        auto c1 = match(
                            c[ "connector" ], "^" ~ Token.CONNECTOR_EXCL ~ "$"
                            ).captures();
                        // Get tracks and offsets.
                        auto c2 = match(
                            c[ "from" ], "^" ~ Pattern.LABEL ~ "$"
                            ).captures();
                        auto c3 = match(
                            c[ "to" ], "^" ~ Pattern.LABEL ~ "$"
                            ).captures();

                        string st1 = to!string( c2[ "t" ] );
                        ubyte  t1  = std.conv.parse!ubyte( st1 );
                        lsn_t  o1;

                        // Offset?
                        if ( !c2[ "m" ].empty() )
                        {
                            string sm1 = to!string( c2[ "m" ] );
                            ubyte  m1  = std.conv.parse!ubyte ( sm1 );
                            string ss1 = to!string( c2[ "s" ] );
                            ubyte  s1  = std.conv.parse!ubyte ( ss1 );
                            string sf1 = to!string( c2[ "f" ] );
                            ubyte  f1  = std.conv.parse!ubyte ( sf1 );

                            o1 = msfToSectors( msf_t( m1, s1, f1 ) );
                        }
                        string st2 = to!string( c3[ "t" ] );
                        ubyte  t2  = std.conv.parse!ubyte( st2 );
                        lsn_t  o2  = -1;

                        // Offset?
                        if ( !c3[ "m" ].empty() )
                        {
                            string sm2 = to!string( c3[ "m" ] );
                            ubyte  m2  = std.conv.parse!ubyte ( sm2 );
                            string ss2 = to!string( c3[ "s" ] );
                            ubyte  s2  = std.conv.parse!ubyte ( ss2 );
                            string sf2 = to!string( c3[ "f" ] );
                            ubyte  f2  = std.conv.parse!ubyte ( sf2 );

                            o2 = msfToSectors( msf_t( m2, s2, f2 ) );
                        }

                        // Exclude label?
                        if ( !c1.empty() )
                        {
                            // Rip up to track t - 1?
                            if ( o2 <= 0 )
                            {
                                t2--;
                                o2 = -1;
                            }
                            else
                            {
                                o2--;
                            }
                        }
                        jobs ~= new ReadFromAudioDiscJob( t1, o1, t2, o2 );
                        continue;
                    }
                }
            }

            // Return jobs.
            return jobs;
        }
    }

    bool parse( Syntax syntax, string[] args, out Config config, out string error )
    {
        try
        {
            // Apply syntax to command line.
            final switch ( syntax )
            {
                case Syntax.HELP:
                    // No arguments passed? Show help!
                    if ( args.length == 1 )
                    {
                        config.help = true;
                        return true;
                    }

                    version ( devel )
                    {
                        getopt(
                            args,
                            std.getopt.config.caseSensitive,
                            std.getopt.config.bundling,
                            "help|h", &config.help,
                            "verbose+|v+", &config.verbose
                            );
                    }
                    else
                    {
                        getopt(
                            args,
                            std.getopt.config.caseSensitive,
                            std.getopt.config.bundling,
                            "help|h", &config.help
                            );

                    }

                    // Drop command.
                    args.popFront();

                    if ( !config.help || args.length )
                    {
                        throw new Exception( "Syntax error" );
                    }

                    // Parsing was successful.
                    return true;
                case Syntax.LIST:
                    version ( devel )
                    {
                        getopt(
                            args,
                            std.getopt.config.caseSensitive,
                            std.getopt.config.bundling,
                            "list|l", &config.list,
                            "verbose+|v+", &config.verbose
                            );
                    }
                    else
                    {
                        getopt(
                            args,
                            std.getopt.config.caseSensitive,
                            std.getopt.config.bundling,
                            "list|l", &config.list
                            );
                    }

                    // Drop command.
                    args.popFront();

                    if ( !config.list || args.length > 1 )
                    {
                        throw new Exception( "Syntax error" );
                    }

                    // Store directory/source to list if passed.
                    if ( args.length == 1 )
                    {
                        // Source does not exist.
                        if ( !exists( args[ 0 ] ) )
                        {
                            config.sourceFile = args[ 0 ];
                            // Source exists.
                        }
                        else
                        {
                            if ( isDir( args[ 0 ] ) )
                            {
                                config.sourceDirectory = args[ 0 ];
                            }
                            else
                            {
                                config.sourceFile = args[ 0 ];
                            }
                        }
                    }

                    // Parsing was successful.
                    return true;
                case Syntax.RIP:
                    string audioFormatDescription = to!string( AudioFormat.WAV );
                    string jobDescriptions;

                    getopt(
                        args,
                        std.getopt.config.caseSensitive,
                        std.getopt.config.bundling,
                        std.getopt.config.passThrough,
                        "verbose+|v+", &config.verbose,
                        "quiet|q", &config.quiet,
                        "dry-run|d", &config.simulate,
                        "paranoia|p", &config.paranoia,
                        "together|t", &config.together,
                        "format|f", &audioFormatDescription,
                        "jobs|j", &jobDescriptions,
                        "speed|s", &config.speed,
                        "swap-bytes|x", &config.swap,
                        "accurate|a", &config.accurate,
                        "calibrate|c", &config.calibrate,
                        "offset|o", &config.offset
                        );

                    // Drop command.
                    args.popFront();

                    // Check for target stdout.
                    if ( args.length && args.back() == "-" )
                    {
                        args.popBack();
                        config.stdout = true;
                    }

                    // Parse source.
                    switch ( args.length )
                    {
                        case 0:
                            throw new Exception( "Missing source" );
                        case 1:
                            config.sourceFile = args[ 0 ];
                            break;
                        default:
                            throw new Exception( "Syntax error" );
                    }

                    // Either verbose or quiet!
                    if ( config.verbose && config.quiet )
                    {
                        throw new Exception( "Switches -v and -q are mutual exclusiv" );
                    }

                    // Set together if target is stdout!
                    if ( config.stdout )
                    {
                        config.together = true;
                    }

                    // Check passed audio format.
                    AudioFormat audioFormat = extractAudioFormat( audioFormatDescription );

                    // Parse job descriptions.
                    config.jobs = JobParser.parse( jobDescriptions );

                    // Set file format/extension.
                    _eponym.setExtension( to!string( audioFormat ).toLower() );

                    // Build target.
                    config.writer        = Writer.Config();
                    config.writer.eponym = _eponym;
                    // Stdout is target?
                    if ( config.stdout )
                    {
                        config.writer.klass  = format( "writers.%s.StdoutWriter", to!string( audioFormat ).toLower() );
                        config.writer.eponym = new StdoutEponym();
                    
                    }
                    // Or file?
                    else
                    {
                        config.writer.klass = format( "writers.%s.FileWriter", to!string( audioFormat ).toLower() );
                    }

                    if ( config.calibrate )
                    {
                        config.accurate = true;

                        if ( config.offset != 0 )
                        {
                            throw new Exception( "Switches -c and -o are mutual exclusiv" );
                        }
                    }

                    // Parsing was successful.
                    return true;
            }
        }
        catch ( Exception e )
        {
            clear( config );
            error = e.msg;
            return false;
        }
    }
}

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


module eponyms;

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
import writers.base;


interface Eponym
{
  void setExtension( string extension );
  string extension();
  string generate( ReadFromDiscJob job, Disc disc );
}

class DefaultEponym : Eponym
{
private:
  string _extension;

  string extend( string basename )
  {
    if ( _extension.empty() ) {
      return basename;
    }

    return format( "%s.%s", basename, _extension );
  }

public:
  this( string extension = "audio" )
  {
    _extension = extension;
  }

  void setExtension( string extension )
  {
    _extension = extension;
  }

  string extension()
  {
    return _extension;
  }

  string generate( ReadFromDiscJob job, Disc disc )
    in
    {
      assert( job !is null && disc !is null );
    }
    body
    {
      // Fetch relevant data.
      SectorRange sr = job.sectorRange( disc );
      Track[] tracks = disc.tracks();
      Track fromTrack = disc.track( sr.from );
      Track toTrack = disc.track( sr.to );

      // Calc filename.

      // Full disc?
      if ( sr.from == tracks.front.firstSector() && sr.to == tracks.back.lastSector() ) {
        return extend( "disc" );
      }


      // Multiple tracks?
      if ( fromTrack != toTrack ) {
        // Both tracks full?
        if ( sr.from == fromTrack.firstSector() && sr.to == toTrack.lastSector() ) {
          return extend( format( "tracks_%02d..%02d", fromTrack.number(), toTrack.number() ) );
        }
        // First track full?
        if ( sr.from == fromTrack.firstSector() ) {
          return extend(
              format( 
                "range_%02d..%02d%s",
                fromTrack.number(),
                toTrack.number(),
                msfToString( sectorsToMsf( sr.to - toTrack.firstSector() ) )
              )
            );
        }
        // Last track full?
        if ( sr.to == toTrack.lastSector() ) {
          return extend(
              format( 
                "range_%02d%s..%02d",
                fromTrack.number(),
                msfToString( sectorsToMsf( sr.from - fromTrack.firstSector() ) ),
                toTrack.number()
              )
            );
        }
        // No track full.
        return extend(
            format( 
              "range_%02d%s..%02d%s",
              fromTrack.number(),
              msfToString( sectorsToMsf( sr.from - fromTrack.firstSector() ) ),
              toTrack.number(),
              msfToString( sectorsToMsf( sr.to - toTrack.firstSector() ) )
            )
          );
      }


      // One track.
      Track track = fromTrack;
      // Full?
      if ( sr.from == track.firstSector() && sr.to == track.lastSector() ) {
        return extend( format( "track_%02d", track.number() ) );
      }
      // From the beginning?
      if ( sr.from == track.firstSector() ) {
        return extend(
            format( 
              "track_%02d%s..%s",
              fromTrack.number(),
              msfToString( msf_t( 0, 0, 0 ) ),
              msfToString( sectorsToMsf( sr.to - fromTrack.firstSector() ) )
            )
          );
      }

      // Other cases.
      return extend(
          format( 
            "track_%02d%s..%s",
            fromTrack.number(),
            msfToString( sectorsToMsf( sr.from - fromTrack.firstSector() ) ),
            msfToString( sectorsToMsf( sr.to - fromTrack.firstSector() ) )
          )
        );
    }
}

final class StdoutEponym : Eponym
{
  string generate( ReadFromDiscJob job, Disc disc )
    in
    {
      assert( job !is null && disc !is null );
    }
    body
    {
      return "stdout";
    }

  void setExtension( string extension ) {}

  string extension() { return ""; }
}

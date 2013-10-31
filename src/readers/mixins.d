/+
  Copyright (C) 2012-2013 Karsten Heinze <karsten@sidenotes.de>

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

module readers.mixins;


mixin template CdIoAudioDiscReader( )
{
    Disc disc()
    {
        // Handle.
        CdIo_t* handle;

        // Open source.
        if ( !( cast( Source!CdIo_t )( _source ) ).open( handle ) )
        {
            throw new Exception( format( "Failed to open %s", _source.path() ) );
        }

        // Media changed since last call?
        if ( !cdio_get_media_changed( handle ) )
        {
            // Maybe we already explored the disc.
            if ( _disc !is null )
                return _disc;
        }

        // Either media is unknown or media changed.

        // Default reader only supports audio discs.
        discmode_t discmode = cdio_get_discmode( handle );
        if ( discmode != discmode_t.CDIO_DISC_MODE_CD_DA &&
             discmode != discmode_t.CDIO_DISC_MODE_CD_MIXED )
        {
            logTrace( format( "Discmode %s is not supported!", to!string( discmode ) ) );
            logDebug( "No audio disc found!" );
            return null;
        }

        logTrace( "Found audio disc." );

        // Build disc.
        Disc disc = new Disc();

        // Retrieve media catalog number and apply to disc.
        char* mcn = cdio_get_mcn( handle );
        disc.setMcn( to!string( mcn ) );
        delete mcn;

        // Retrieve tracks and add them to disc.
        track_t        tracks = cdio_get_num_tracks( handle );
        track_format_t trackFormat;
        lsn_t          firstSector, lastSector;
        for ( track_t track = 1; track <= tracks; track++ )
        {
            trackFormat = cdio_get_track_format( handle, track );
            firstSector = cdio_get_track_lsn( handle, track );
            lastSector  = cdio_get_track_last_lsn( handle, track );
            if ( trackFormat == track_format_t.TRACK_FORMAT_AUDIO )
            {
                logTrace( format( "Found audio track %d (%d - %d).", track, firstSector, lastSector ) );
            }
            else
            {
                logTrace( format( "Found non audio track %d (%d - %d).", track, firstSector, lastSector ) );
            }

            disc.addTrack(
                new Track(
                    track,
                    firstSector,
                    lastSector,
                    trackFormat == track_format_t.TRACK_FORMAT_AUDIO
                    )
                );

            // In case tracks is 255.
            if ( track == track_t.max )
                break;
        }

        // Log what we found.
        string word = ( disc.mcn().length ? format( " %s", disc.mcn() ) : "" );
        logDebug( format( "Found audio disc%s with %d tracks.", word, tracks ) );

        // Cache result.
        _disc = disc;

        return _disc;
    }
}

mixin template RatioLogger( )
{
    void logRatio(
        uint current,
        uint previous,
        uint overall,
        ubyte width = 80,
        LogLevel logLevel = LogLevel.INFO
        )
    {
        version ( devel )
        {
            string prefix = format( " %s: ", this.type() );
        }
        else
        {
            string prefix = ": ";
        }

        // Available width for status bar (without borders |).
        ubyte nettoWidth = cast( ubyte )(
            width -
            ( to!string( logLevel ).length ) -
            ( prefix.length ) -
            2
            );

        // Begin.
        if ( current == 0 )
        {
            for ( ubyte i = 1; i < width; i++ )
            {
                log( logLevel, " ", false, false );
            }
            log( logLevel, "|\r", false, false );
            log( logLevel, "|", false );
            return;
        }

        // In between.
        double previousRatio = cast( double )( previous ) / overall;
        double currentRatio  = cast( double )( current ) / overall;
        ubyte  previousWidth = cast( ubyte )( previousRatio * nettoWidth );
        ubyte  currentWidth  = cast( ubyte )( currentRatio * nettoWidth );

        if ( currentWidth > previousWidth )
        {
            for ( ubyte i = 0; i < ( currentWidth - previousWidth ); i++ )
            {
                log( logLevel, "=", false, false );
            }
        }

        // End.
        if ( current == overall )
        {
            log( logLevel, "|", true, false );
            return;
        }
    }
}

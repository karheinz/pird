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

module c.cdio.track;

import c.cdio.types;


extern ( C ) :
const char* track_format2str[ 6 ];

enum track_format_t
{
    TRACK_FORMAT_AUDIO,
    TRACK_FORMAT_CDI,
    TRACK_FORMAT_XA,
    TRACK_FORMAT_DATA,
    TRACK_FORMAT_PSX,
    TRACK_FORMAT_ERROR
};

enum track_flag_t
{
    CDIO_TRACK_FLAG_FALSE,
    CDIO_TRACK_FLAG_TRUE,
    CDIO_TRACK_FLAG_ERROR,
    CDIO_TRACK_FLAG_UNKNOWN
};

struct track_flags_s
{
    track_flag_t preemphasis;
    track_flag_t copy_permit;
    int          channels;
};
alias track_flags_s track_flags_t;

enum cdio_track_enums
{
    CDIO_CDROM_LBA           = 0x01,
    CDIO_CDROM_MSF           = 0x02,
    CDIO_CDROM_DATA_TRACK    = 0x04,
    CDIO_CDROM_CDI_TRACK     = 0x10,
    CDIO_CDROM_XA_TRACK      = 0x20,
    CDIO_CD_MAX_TRACKS       = 99,
    CDIO_CDROM_LEADOUT_TRACK = 0xAA,
    CDIO_INVALID_TRACK       = 0xFF,
};
alias cdio_track_enums.CDIO_CD_MAX_TRACKS CDIO_CD_MAX_TRACKS;

enum
{
    CDIO_CD_MIN_TRACK_NO = 1
}

enum trackmode_t
{
    AUDIO,
    MODE1,
    MODE1_RAW,
    MODE2,
    MODE2_FORM1,
    MODE2_FORM2,
    MODE2_FORM_MIX,
    MODE2_RAW
};

cdtext_t* cdio_get_cdtext( CdIo_t* p_cdio, track_t i_track );
track_t cdio_get_first_track_num( const CdIo_t* p_cdio );
track_t cdio_get_last_track_num( const CdIo_t* p_cdio );
track_t cdio_get_track( const CdIo_t* p_cdio, lsn_t lsn );
int cdio_get_track_channels( const CdIo_t* p_cdio, track_t i_track );
track_flag_t cdio_get_track_copy_permit( const CdIo_t* p_cdio, track_t i_track );
track_format_t cdio_get_track_format( const CdIo_t* p_cdio, track_t i_track );
bool cdio_get_track_green( const CdIo_t* p_cdio, track_t i_track );
lsn_t cdio_get_track_last_lsn( const CdIo_t* p_cdio, track_t i_track );
lba_t cdio_get_track_lba( const CdIo_t* p_cdio, track_t i_track );
lsn_t cdio_get_track_lsn( const CdIo_t* p_cdio, track_t i_track );
lba_t cdio_get_track_pregap_lba( const CdIo_t* p_cdio, track_t i_track );
lsn_t cdio_get_track_pregap_lsn( const CdIo_t* p_cdio, track_t i_track );
char* cdio_get_track_isrc( const CdIo_t* p_cdio, track_t i_track );
bool cdio_get_track_msf( const CdIo_t* p_cdio, track_t i_track, /*out*/ msf_t* msf );
track_flag_t cdio_get_track_preemphasis( const CdIo_t* p_cdio, track_t i_track );
uint cdio_get_track_sec_count( const CdIo_t* p_cdio, track_t i_track );

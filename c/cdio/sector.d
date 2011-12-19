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

module c.cdio.sector;

import c.cdio.types;


extern (C):
  enum { 
    CDIO_SUBCHANNEL_SUBQ_DATA        = 0,
    CDIO_SUBCHANNEL_CURRENT_POSITION = 1,
    CDIO_SUBCHANNEL_MEDIA_CATALOG    = 2,
    CDIO_SUBCHANNEL_TRACK_ISRC       = 3
  }
        
  enum flag_t {
   NONE               = 0x00,
   PRE_EMPHASIS       = 0x01,
   COPY_PERMITTED     = 0x02,
   DATA               = 0x04,
   FOUR_CHANNEL_AUDIO = 0x08,
   SCMS               = 0x10
  };
        
  enum {
    CDIO_PREGAP_SECTORS  = 150,
    CDIO_POSTGAP_SECTORS = 150
  }

  enum cdio_cd_enums {
    CDIO_CD_MINS =              74,
    CDIO_CD_SECS_PER_MIN =      60,
    CDIO_CD_FRAMES_PER_SEC =    75,
    CDIO_CD_SYNC_SIZE =         12,
    CDIO_CD_NUM_OF_CHUNKS =     98,
    CDIO_CD_FRAMESIZE_SUB =     96,
    CDIO_CD_HEADER_SIZE =        4,
    CDIO_CD_SUBHEADER_SIZE =     8,
    CDIO_CD_ECC_SIZE =         276,
    CDIO_CD_FRAMESIZE =       2048,
    CDIO_CD_FRAMESIZE_RAW =   2352,
    CDIO_CD_FRAMESIZE_RAWER = 2646,
    CDIO_CD_FRAMESIZE_RAW1  = 2340,
    CDIO_CD_FRAMESIZE_RAW0  = 2336,
    CDIO_CD_MAX_SESSIONS =      99,
    CDIO_CD_MIN_SESSION_NO =     1,
    CDIO_CD_MAX_LSN =       450150,
    CDIO_CD_MIN_LSN      = -450150
  };

  enum {
    CDIO_CD_MINS = 74,
    CDIO_CD_SECS_PER_MIN = 60,
    CDIO_CD_FRAMES_PER_SEC = 75,
    CDIO_CD_SYNC_SIZE = 12,
    CDIO_CD_CHUNK_SIZE = 24,
    CDIO_CD_NUM_OF_CHUNKS = 98,
    CDIO_CD_FRAMESIZE_SUB = 96,
    CDIO_CD_HEADER_SIZE = 4,
    CDIO_CD_SUBHEADER_SIZE = 8,
    CDIO_CD_EDC_SIZE = 4,
    CDIO_CD_M1F1_ZERO_SIZE = 8,
    CDIO_CD_ECC_SIZE = 276,
    CDIO_CD_FRAMESIZE = 2048,
    CDIO_CD_FRAMESIZE_RAW = 2352,
    CDIO_CD_FRAMESIZE_RAWER = 2646,
    CDIO_CD_FRAMESIZE_RAW1 = (CDIO_CD_FRAMESIZE_RAW-CDIO_CD_SYNC_SIZE), /*2340*/
    CDIO_CD_FRAMESIZE_RAW0 = (CDIO_CD_FRAMESIZE_RAW-CDIO_CD_SYNC_SIZE-CDIO_CD_HEADER_SIZE), /*2336*/
    CDIO_CD_XA_HEADER = (CDIO_CD_HEADER_SIZE+CDIO_CD_SUBHEADER_SIZE), 
    CDIO_CD_XA_TAIL = (CDIO_CD_EDC_SIZE+CDIO_CD_ECC_SIZE),
    CDIO_CD_XA_SYNC_HEADER = (CDIO_CD_SYNC_SIZE+CDIO_CD_XA_HEADER) 
  }
        
  const ubyte CDIO_SECTOR_SYNC_HEADER[ CDIO_CD_SYNC_SIZE ];

  enum m2_sector_enums {
    M2F2_SECTOR_SIZE  = 2324,
    M2SUB_SECTOR_SIZE = 2332,
    M2RAW_SECTOR_SIZE = 2336
  };
      
  alias m2_sector_enums.M2F2_SECTOR_SIZE M2F2_SECTOR_SIZE;
  alias m2_sector_enums.M2SUB_SECTOR_SIZE M2SUB_SECTOR_SIZE;
  alias m2_sector_enums.M2RAW_SECTOR_SIZE M2RAW_SECTOR_SIZE;
      
  enum {
    CDIO_CD_MAX_SESSIONS = 99,
    CDIO_CD_MIN_SESSION_NO = 1,
    CDIO_CD_MAX_LSN = 450150,
    CDIO_CD_MIN_LSN = -450150,
    CDIO_CD_FRAMES_PER_MIN = ( CDIO_CD_FRAMES_PER_SEC * CDIO_CD_SECS_PER_MIN ),
    CDIO_CD_74MIN_SECTORS = ( 74 * CDIO_CD_FRAMES_PER_MIN ),
    CDIO_CD_80MIN_SECTORS = ( 80 * CDIO_CD_FRAMES_PER_MIN ),
    CDIO_CD_90MIN_SECTORS = ( 90 * CDIO_CD_FRAMES_PER_MIN ),
    CDIO_CD_MAX_SECTORS = ( 100 * CDIO_CD_FRAMES_PER_MIN - CDIO_PREGAP_SECTORS ),
    msf_t_SIZEOF = 3
  }
      
  char* cdio_lba_to_msf_str( lba_t i_lba );
  char* cdio_msf_to_str( const msf_t *p_msf );
  lba_t cdio_lba_to_lsn( lba_t i_lba );
  void cdio_lba_to_msf( lba_t i_lba, msf_t* p_msf );
  lba_t cdio_lsn_to_lba( lsn_t i_lsn );
  void cdio_lsn_to_msf(lsn_t i_lsn, msf_t* p_msf );
  lba_t cdio_msf_to_lba( const msf_t* p_msf );
  lsn_t cdio_msf_to_lsn( const msf_t* p_msf );
  lba_t cdio_msf3_to_lba(
      uint minutes,
      uint seconds,
      uint frames
    );
  lba_t cdio_mmssff_to_lba( const char* psz_mmssff );

  alias CDIO_CD_FRAMESIZE_RAW CD_FRAMESIZE_RAW;

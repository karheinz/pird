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

module c.cdio.cdda;

import c.cdio.sector;
import c.cdio.track;
import c.cdio.types;


extern (C):
  struct cdrom_paranoia_s;
  alias cdrom_paranoia_s cdrom_paranoia_t;

  enum paranoia_cdda_enums_t {
    CDDA_MESSAGE_FORGETIT = 0,
    CDDA_MESSAGE_PRINTIT  = 1,
    CDDA_MESSAGE_LOGIT    = 2,
    CD_FRAMESAMPLES       = CDIO_CD_FRAMESIZE_RAW / 4,
    MAXTRK                = ( CDIO_CD_MAX_TRACKS + 1 )
  }

  struct TOC_s {	
    ubyte bTrack;
    int dwStartSector;
  };
  alias TOC_s TOC_t;

  struct cdrom_drive_s {
    CdIo_t* p_cdio;
    int opened;
    char* cdda_device_name;
    char* drive_model;
    int drive_type;
    int bigendianp;
    int nsectors;
    int cd_extra;
    bool b_swap_bytes;
    track_t tracks;
    TOC_t disc_toc[ paranoia_cdda_enums_t.MAXTRK ];
    lsn_t audio_first_sector;
    lsn_t audio_last_sector;
    int errordest;
    int messagedest;
    char* errorbuf;
    char* messagebuf;
    int *enable_cdda( cdrom_drive_t* d, int onoff );
    int *read_toc( cdrom_drive_t* d );
    long *read_audio( cdrom_drive_t* d, void* p, lsn_t begin, long sectors );
    int *set_speed( cdrom_drive_t* d, int speed );
    int error_retry;
    int report_all;
    int is_atapi;
    int is_mmc;
    int i_test_flags;
  };
  alias cdrom_drive_s cdrom_drive_t;

  enum paranoia_jitter_t {
    CDDA_TEST_JITTER_SMALL   = 1,
    CDDA_TEST_JITTER_LARGE   = 2,
    CDDA_TEST_JITTER_MASSIVE = 3,
    CDDA_TEST_FRAG_SMALL     = ( 1 << 3 ),
    CDDA_TEST_FRAG_LARGE     = ( 2 << 3 ),
    CDDA_TEST_FRAG_MASSIVE   = ( 3 << 3 ),
    CDDA_TEST_UNDERRUN       = 64 
  }

  enum {
    CDDA_TEST_ALWAYS_JITTER = 4,
    CDDA_TEST_FRAG_SMALL = ( 1 << 3 ),
    CDDA_TEST_FRAG_LARGE = ( 2 << 3 ),
    CDDA_TEST_FRAG_MASSIVE = ( 3 << 3 ),
    CDDA_TEST_UNDERRUN = 64,
    CDDA_TEST_SCRATCH = 128,
    CDDA_TEST_BOGUS_BYTES = 256,
    CDDA_TEST_DROPDUPE_BYTES = 512
  }

  cdrom_drive_t* cdio_cddap_find_a_cdrom( int messagedest, char** ppsz_message );
  cdrom_drive_t* cdio_cddap_identify(
      const char* psz_device, 
      int messagedest, 
      char** ppsz_message
    );
  cdrom_drive_t* cdio_cddap_identify_cdio(
      CdIo_t* p_cdio, 
      int messagedest,
      char** ppsz_messages
    );
  int cdio_cddap_speed_set( cdrom_drive_t* d, int speed );
  void cdio_cddap_verbose_set( cdrom_drive_t* d, int err_action, int mes_action );
  char* cdio_cddap_messages( cdrom_drive_t* d );
  char* cdio_cddap_errors( cdrom_drive_t* d );
  bool cdio_cddap_close_no_free_cdio( cdrom_drive_t* d );
  int cdio_cddap_close( cdrom_drive_t* d );
  int cdio_cddap_open( cdrom_drive_t* d );
  long cdio_cddap_read( cdrom_drive_t* d, void* p_buffer, lsn_t beginsector, long sectors );
  lsn_t cdio_cddap_track_firstsector( cdrom_drive_t* d, track_t i_track );
  lsn_t cdio_cddap_track_lastsector( cdrom_drive_t* d, track_t i_track );
  track_t cdio_cddap_tracks( cdrom_drive_t* d );
  int cdio_cddap_sector_gettrack( cdrom_drive_t* d, lsn_t lsn );
  int cdio_cddap_track_channels( cdrom_drive_t* d, track_t i_track );
  int cdio_cddap_track_audiop( cdrom_drive_t* d, track_t i_track );
  int cdio_cddap_track_copyp( cdrom_drive_t* d, track_t i_track );
  int cdio_cddap_track_preemp( cdrom_drive_t* d, track_t i_track );
  lsn_t cdio_cddap_disc_firstsector( cdrom_drive_t* d );
  lsn_t cdio_cddap_disc_lastsector( cdrom_drive_t* d );
  int data_bigendianp( cdrom_drive_t* d );

  enum transport_error_t {
    TR_OK =            0,
    TR_EWRITE =        1  /**< Error writing packet command (transport) */,
    TR_EREAD =         2  /**< Error reading packet data (transport) */,
    TR_UNDERRUN =      3  /**< Read underrun */,
    TR_OVERRUN =       4  /**< Read overrun */,
    TR_ILLEGAL =       5  /**< Illegal/rejected request */,
    TR_MEDIUM =        6  /**< Medium error */,
    TR_BUSY =          7  /**< Device busy */,
    TR_NOTREADY =      8  /**< Device not ready */,
    TR_FAULT =         9  /**< Device failure */,
    TR_UNKNOWN =      10  /**< Unspecified error */,
    TR_STREAMING =    11  /**< loss of streaming */,
  };
    
  const char* strerror_tr[] = [
    "Success",
    "Error writing packet command to device",
    "Error reading command from device",
    "SCSI packet data underrun (too little data)",
    "SCSI packet data overrun (too much data)",
    "Illegal SCSI request (rejected by target)",
    "Medium reading data from medium",
    "Device busy",
    "Device not ready",
    "Target hardware fault",
    "Unspecified error",
    "Drive lost streaming"
  ];


  /** For compatibility with good ol' paranoia */
  alias cdio_cddap_find_a_cdrom cdda_find_a_cdrom; 
  alias cdio_cddap_identify cdda_identify;
  alias cdio_cddap_speed_set cdda_speed_set;
  alias cdio_cddap_verbose_set cdda_verbose_set;
  alias cdio_cddap_messages cdda_messages;
  alias cdio_cddap_errors cdda_errors;
  alias cdio_cddap_close cdda_close;
  alias cdio_cddap_open cdda_open;               
  alias cdio_cddap_read cdda_read;
  alias cdio_cddap_track_firstsector cdda_track_firstsector;
  alias cdio_cddap_track_lastsector cdda_track_lastsector;
  alias cdio_cddap_tracks cdda_tracks;
  alias cdio_cddap_sector_gettrack cdda_sector_gettrack;
  alias cdio_cddap_track_channels cdda_track_channels;
  alias cdio_cddap_track_audiop cdda_track_audiop;
  alias cdio_cddap_track_copyp cdda_track_copyp;
  alias cdio_cddap_track_preemp cdda_track_preemp;
  alias cdio_cddap_disc_firstsector cdda_disc_firstsector;
  alias cdio_cddap_disc_lastsector cdda_disc_lastsector;
  alias cdrom_drive_t cdrom_drive;

  paranoia_jitter_t debug_paranoia_jitter;
  paranoia_cdda_enums_t debug_paranoia_cdda_enums;

/+
  Copyright (C) 2012 Karsten Heinze <karsten.heinze@sidenotes.de>

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

module c.cdio.read;

import c.cdio.device;
import c.cdio.types;


extern (C):
  /** All the different ways a block/sector can be read. */
  enum cdio_read_mode {
    CDIO_READ_MODE_AUDIO,  /**< CD-DA, audio, Red Book */
    CDIO_READ_MODE_M1F1,   /**< Mode 1 Form 1 */
    CDIO_READ_MODE_M1F2,   /**< Mode 1 Form 2 */
    CDIO_READ_MODE_M2F1,   /**< Mode 2 Form 1 */
    CDIO_READ_MODE_M2F2    /**< Mode 2 Form 2 */
  }; 
  alias cdio_read_mode cdio_read_mode_t;
  

  off_t cdio_lseek( const CdIo_t *p_cdio, off_t offset, int whence );
  ssize_t cdio_read( const CdIo_t *p_cdio, void *p_buf, size_t i_size );
  driver_return_code_t cdio_read_audio_sector( const CdIo_t *p_cdio, void *p_buf, lsn_t i_lsn );
  driver_return_code_t cdio_read_audio_sectors( const CdIo_t *p_cdio, void *p_buf, lsn_t i_lsn, uint32_t i_blocks );
  driver_return_code_t cdio_read_data_sectors (
      const CdIo_t *p_cdio, 
      void *p_buf, lsn_t i_lsn,
      uint16_t i_blocksize,
      uint32_t i_blocks
    );
  driver_return_code_t cdio_read_mode1_sector(
      const CdIo_t *p_cdio, 
      void *p_buf, lsn_t i_lsn, 
      bool b_form2
    );
  driver_return_code_t cdio_read_mode1_sectors(
      const CdIo_t *p_cdio, 
      void *p_buf, lsn_t i_lsn, 
      bool b_form2, 
      uint32_t i_blocks
    );
  driver_return_code_t cdio_read_mode2_sector(
      const CdIo_t *p_cdio, 
      void *p_buf, lsn_t i_lsn, 
      bool b_form2
    );
  driver_return_code_t cdio_read_sector(
      const CdIo_t *p_cdio, void *p_buf, 
      lsn_t i_lsn, 
      cdio_read_mode_t read_mode
    );
  driver_return_code_t cdio_read_mode2_sectors(
      const CdIo_t *p_cdio, 
      void *p_buf, lsn_t i_lsn, 
      bool b_form2, 
      uint32_t i_blocks
    );
  driver_return_code_t cdio_read_sectors(
      const CdIo_t *p_cdio, void *p_buf, 
      lsn_t i_lsn, 
      cdio_read_mode_t read_mode,
      uint32_t i_blocks
    );

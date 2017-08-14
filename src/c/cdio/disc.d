/+
  Copyright (C) 2011-2017 Karsten Heinze <karsten@sidenotes.de>

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

module c.cdio.disc;

import c.cdio.types;


extern ( C ) :
enum discmode_t
{
    CDIO_DISC_MODE_CD_DA,           /**< CD-DA */
    CDIO_DISC_MODE_CD_DATA,         /**< CD-ROM form 1 */
    CDIO_DISC_MODE_CD_XA,           /**< CD-ROM XA form2 */
    CDIO_DISC_MODE_CD_MIXED,        /**< Some combo of above. */
    CDIO_DISC_MODE_DVD_ROM,         /**< DVD ROM (e.g. movies) */
    CDIO_DISC_MODE_DVD_RAM,         /**< DVD-RAM */
    CDIO_DISC_MODE_DVD_R,           /**< DVD-R */
    CDIO_DISC_MODE_DVD_RW,          /**< DVD-RW */
    CDIO_DISC_MODE_HD_DVD_ROM,      /**< HD DVD-ROM */
    CDIO_DISC_MODE_HD_DVD_RAM,      /**< HD DVD-RAM */
    CDIO_DISC_MODE_HD_DVD_R,        /**< HD DVD-R */
    CDIO_DISC_MODE_DVD_PR,          /**< DVD+R */
    CDIO_DISC_MODE_DVD_PRW,         /**< DVD+RW */
    CDIO_DISC_MODE_DVD_PRW_DL,      /**< DVD+RW DL */
    CDIO_DISC_MODE_DVD_PR_DL,       /**< DVD+R DL */
    CDIO_DISC_MODE_DVD_OTHER,       /**< Unknown/unclassified DVD type */
    CDIO_DISC_MODE_NO_INFO,
    CDIO_DISC_MODE_ERROR,
    CDIO_DISC_MODE_CD_I         /**< CD-i. */
};

extern const char*[] discmode2str;

discmode_t cdio_get_discmode( CdIo_t* p_cdio );
lsn_t cdio_get_disc_last_lsn( const CdIo_t* p_cdio );
ubyte cdio_get_joliet_level( const CdIo_t* p_cdio );
char* cdio_get_mcn( const CdIo_t* p_cdio );
track_t cdio_get_num_tracks( const CdIo_t* p_cdio );
bool cdio_is_discmode_cdrom( discmode_t discmode );
bool cdio_is_discmode_dvd( discmode_t discmode );

alias cdio_get_disc_last_lsn cdio_stat_size;

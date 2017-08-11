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


module c.cdio.device;

import c.cdio.types;


extern ( C ) :
// Enumerations.

// Drivers.
enum Driver : uint
{
    UNKNOWN,
    AIX,
    BSDI,
    FREEBSD,
    NETBSD,
    LINUX,
    SOLARIS,
    OSX,
    WIN32,
    CDRDAO,
    BINCUE,
    NRG,
    DEVICE
}

enum driver_return_code
{
    DRIVER_OP_MMC_SENSE_DATA = -8,
    DRIVER_OP_NO_DRIVER,
    DRIVER_OP_BAD_POINTER,
    DRIVER_OP_BAD_PARAMETER,
    DRIVER_OP_NOT_PERMITTED,
    DRIVER_OP_UNINIT,
    DRIVER_OP_UNSUPPORTED,
    DRIVER_OP_ERROR,
    DRIVER_OP_SUCCESS
}
alias driver_return_code driver_return_code_t;

// Device capabilities.
enum CommonCapability : uint
{
    ERROR   = 0x40000,
    UNKNOWN = 0x80000
}

enum MiscellaneousCapability : uint
{
    CLOSE_TRAY    = 0x00001,
    EJECT         = 0x00002,
    LOCK          = 0x00004,
    SELECT_SPEED  = 0x00008,
    SELECT_DISC   = 0x00010,
    MULTI_SESSION = 0x00020,
    MEDIA_CHANGED = 0x00080,
    RESET         = 0x00100,
    FILE          = 0x20000
}

enum ReadCapability : uint
{
    AUDIO       = 0x00001,
    CD_DA       = 0x00002,
    CD_G        = 0x00004,
    CD_R        = 0x00008,
    CD_RW       = 0x00010,
    DVD_R       = 0x00020,
    DVD_R_P     = 0x00040,
    DVD_RAM     = 0x00080,
    DVD_ROM     = 0x00100,
    DVD_RW      = 0x00200,
    DVD_RW_P    = 0x00400,
    C2_ERRS     = 0x00800,
    MODE2_FORM1 = 0x01000,
    MODE2_FORM2 = 0x02000,
    MCN         = 0x04000,
    ISRC        = 0x08000
}

enum WriteCapability : uint
{
    CD_R                 = 0x00001,   // drive can write CD-R
    CD_RW                = 0x00002,   // drive can write CD-RW
    DVD_R                = 0x00004,   // drive can write DVD-R
    DVD_R_P              = 0x00008,   // drive can write DVD+R
    DVD_RAM              = 0x00010,   // drive can write DVD-RAM
    DVD_RW               = 0x00020,   // drive can write DVD-RW
    DVD_RW_P             = 0x00040,   // drive can write DVD+RW
    MT_RAINIER           = 0x00080,   // Mount Rainier
    BURN_PROOF           = 0x00100,   // burn proof
    CD                   = ( CD_R | CD_RW ),
    DVD                  = ( DVD_R | DVD_R_P | DVD_RAM | DVD_RW | DVD_RW_P ),
    CDIO_DRIVE_CAP_WRITE = ( CD | DVD )
}

// Used to store drive info.
struct cdio_hwinfo_t
{
    char[ 8 + 1 ] psz_vendor;
    char[ 16 + 1 ] psz_model;
    char[ 4 + 1 ] psz_revision;
};


// Types.
alias uint driver_id_t;
alias int  cdio_fs_anal_t;

// API functions.
char** cdio_get_devices( driver_id_t driver_id );
char** cdio_get_devices_ret( /*in/out*/ driver_id_t* p_driver_id );
CdIo_t* cdio_open( const char* psz_source, driver_id_t driver_id );
void cdio_destroy( CdIo_t* handle );
void cdio_free_device_list( char** device_list );
char** cdio_get_devices_with_cap(
    char*[] ppsz_search_devices,   // in
    cdio_fs_anal_t capabilities,
    bool b_any
    );
char** cdio_get_devices_with_cap_ret(
    ref char*[] ppsz_search_devices,   // in
    cdio_fs_anal_t capabilities,
    bool b_any,
    driver_id_t* p_driver_id   // out
    );

void cdio_get_drive_cap(
    const CdIo_t* p_cdio,
    uint* p_read_cap,
    uint* p_write_cap,
    uint* p_misc_cap
    );
void cdio_get_drive_cap_dev(
    const char* device,
    uint* p_read_cap,
    uint* p_write_cap,
    uint* p_misc_cap
    );

char* cdio_driver_describe( uint driver );
bool cdio_have_driver( uint driver );
bool cdio_is_device( char* path, uint driver );
bool cdio_get_hwinfo( const CdIo_t* p_cdio, /*out*/ cdio_hwinfo_t* p_hw_info );
int cdio_get_media_changed( CdIo_t* p_cdio );
driver_return_code_t cdio_set_speed(
    const CdIo_t* p_cdio,
    int i_drive_speed
    );

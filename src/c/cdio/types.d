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

module c.cdio.types;


extern (C):
  // opaque structure for device handle
  struct _CdIo;
  alias _CdIo CdIo_t;

  // minutes, seconds, frame structure
  struct msf_s {
    ubyte m, s, f;
  };
  alias msf_s msf_t;

  // logical block address
  alias int lba_t;
  // logical sector number
  alias int lsn_t;

  alias ubyte track_t;
  alias ubyte session_t;

  // basic types for cd text
  enum {
    MIN_CDTEXT_FIELD = 0,
    MAX_CDTEXT_FIELDS = 13
  }

  struct cdtext {
    char* field[ MAX_CDTEXT_FIELDS ];
  };
  alias cdtext cdtext_t;

  /*
   * Original declarations can be found in:
   *    /usr/include/types.h
   *    /usr/include/bits/types.h
   *    /usr/include/bits/typesizes.h
   */
  alias uint uint32_t;
  alias ushort uint16_t;
  alias long off_t;
  alias int ssize_t;

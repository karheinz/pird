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

module c.cdio.cdtext;

import c.cdio.types;


extern ( C ) :
enum cdtext_field_t
{
    CDTEXT_ARRANGER   = 0,    /**< name(s) of the arranger(s) */
    CDTEXT_COMPOSER   = 1,    /**< name(s) of the composer(s) */
    CDTEXT_DISCID     = 2,    /**< disc identification information */
    CDTEXT_GENRE      = 3,    /**< genre identification and genre information */
    CDTEXT_MESSAGE    = 4,    /**< ISRC code of each track */
    CDTEXT_ISRC       = 5,    /**< message(s) from the content provider or artist */
    CDTEXT_PERFORMER  = 6,    /**< name(s) of the performer(s) */
    CDTEXT_SIZE_INFO  = 7,    /**< size information of the block */
    CDTEXT_SONGWRITER = 8,    /**< name(s) of the songwriter(s) */
    CDTEXT_TITLE      = 9,    /**< title of album name or track titles */
    CDTEXT_TOC_INFO   = 10,   /**< table of contents information */
    CDTEXT_TOC_INFO2  = 11,   /**< second table of contents information */
    CDTEXT_UPC_EAN    = 12,
    CDTEXT_INVALID    = MAX_CDTEXT_FIELDS
};

immutable( char )[] cdtext_field2str( cdtext_field_t i );
void cdtext_init( cdtext_t* cdtext );
void cdtext_destroy( cdtext_t* cdtext );
char* cdtext_get( cdtext_field_t key, const cdtext_t* cdtext );
immutable( char )[] cdtext_get_const( cdtext_field_t key, const cdtext_t * cdtext );
cdtext_field_t cdtext_is_keyword( const char* key );
void cdtext_set( cdtext_field_t key, const char* value, cdtext_t* cdtext );

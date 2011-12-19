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

module c.cdio.logging;

import c.cdio.types;


extern (C):
  /**
   * The different log levels supported.
   */
  enum cdio_log_level_t : ubyte {
    CDIO_LOG_DEBUG = 1, /**< Debug-level messages - helps debug what's up. */
    CDIO_LOG_INFO,      /**< Informational - indicates perhaps something of 
                             interest. */
    CDIO_LOG_WARN,      /**< Warning conditions - something that looks funny. */
    CDIO_LOG_ERROR,     /**< Error conditions - may terminate program.  */
    CDIO_LOG_ASSERT     /**< Critical conditions - may abort program. */
  };

  alias void function( cdio_log_level_t level, const char* message ) cdio_log_handler_t;
  cdio_log_handler_t cdio_log_set_handler( cdio_log_handler_t new_handler );

  void cdio_debug( const char* message, ... );
  void cdio_info( const char* message, ... );
  void cdio_warn( const char* message, ... );
  void cdio_error( const char* message, ... );

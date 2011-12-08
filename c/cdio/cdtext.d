module c.cdio.cdtext;

import c.cdio.types;

extern (C):

  
  enum cdtext_field_t {
    CDTEXT_ARRANGER   =  0,   /**< name(s) of the arranger(s) */
    CDTEXT_COMPOSER   =  1,   /**< name(s) of the composer(s) */
    CDTEXT_DISCID     =  2,   /**< disc identification information */
    CDTEXT_GENRE      =  3,   /**< genre identification and genre information */
    CDTEXT_MESSAGE    =  4,   /**< ISRC code of each track */
    CDTEXT_ISRC       =  5,   /**< message(s) from the content provider or artist */
    CDTEXT_PERFORMER  =  6,   /**< name(s) of the performer(s) */
    CDTEXT_SIZE_INFO  =  7,   /**< size information of the block */
    CDTEXT_SONGWRITER =  8,   /**< name(s) of the songwriter(s) */
    CDTEXT_TITLE      =  9,   /**< title of album name or track titles */
    CDTEXT_TOC_INFO   = 10,   /**< table of contents information */
    CDTEXT_TOC_INFO2  = 11,   /**< second table of contents information */
    CDTEXT_UPC_EAN    = 12,
    CDTEXT_INVALID    = MAX_CDTEXT_FIELDS
  };

  immutable( char )[] cdtext_field2str( cdtext_field_t i );
  void cdtext_init( cdtext_t* cdtext );
  void cdtext_destroy(cdtext_t* cdtext );
  char* cdtext_get( cdtext_field_t key, const cdtext_t* cdtext );
  immutable( char )[] cdtext_get_const( cdtext_field_t key, const cdtext_t* cdtext );
  cdtext_field_t cdtext_is_keyword( const char* key );
  void cdtext_set( cdtext_field_t key, const char* value, cdtext_t* cdtext );

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

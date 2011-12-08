module readers.base;

import introspection;
import log;
import media;
import sources.base;


interface Reader : introspection.Interface
{
  void setSource( Source source );
  Disc disc();
  long read( Mask mask = null );
  void connect( void delegate( string, LogLevel, string ) signalHandler );
  void disconnect( void delegate( string, LogLevel, string ) signalHandler );
  void emit( string emitter, LogLevel level, string message );
}

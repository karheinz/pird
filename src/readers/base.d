/+
  Copyright (C) 2011,2012 Karsten Heinze <karsten@sidenotes.de>

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

module readers.base;

import std.array;

import c.cdio.types;

import introspection;
import log;
import media;
import readers.jobs;
import sources.base;
import writers.base;


interface DiscReader : introspection.Interface
{
  void setSource( GenericSource source );
  Disc disc();
  void add( ReadFromDiscJob job );
  void replace( ReadFromDiscJob from, ReadFromDiscJob[] to );
  void clear();
  bool read();
  void setWriterConfig( Writer.Config config );
  void setSpeed( ubyte speed );
  ReadFromDiscJob[] jobs();
  ReadFromDiscJob[] unsatisfiableJobs();
  void connect( void delegate( string, LogLevel, string ) signalHandler );
  void disconnect( void delegate( string, LogLevel, string ) signalHandler );
  void emit( string emitter, LogLevel level, string message );
}

interface AudioDiscReader : DiscReader
{
}

abstract class AbstractAudioDiscReader : AudioDiscReader
{
protected:
  GenericSource _source;
  Disc _disc;
  ubyte _speed;
  Writer.Config _writerConfig;
  ReadFromDiscJob[] _jobs;

public:
  void setSource( GenericSource source )
  {
    _source = source;
    _disc = null;
  }

  void setSpeed( ubyte speed )
  {
    _speed = speed;
  }

  void setWriterConfig( Writer.Config config )
  {
    _writerConfig = config;
  }

  void add( ReadFromDiscJob job )
  {
    _jobs ~= job;
  }

  void replace( ReadFromDiscJob from, ReadFromDiscJob[] to )
  {
    foreach( i, job; _jobs ) {
      if ( job is from ) {
        _jobs.replaceInPlace( i, i + 1, to );
        return;
      }
    }
  }

  void clear()
  {
    _jobs.clear();
  }

  ReadFromDiscJob[] jobs() {
    return _jobs;
  }

  ReadFromDiscJob[] unsatisfiableJobs() {
    ReadFromDiscJob[] result;
    foreach ( job; _jobs ) {
      if ( ! job.fits( disc() ) ) {
        result ~= job;
      }
    }

    return result;
  };


  mixin introspection.Initial;
}
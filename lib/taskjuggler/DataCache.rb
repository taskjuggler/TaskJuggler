#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DataCache.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'time'
require 'singleton'

class TaskJuggler

  # These are the entries in the DataCache. They store a value and an access
  # counter. The counter can be read and written externally.
  class DataCacheEntry

    attr_accessor :hits

    # Create a new DataCacheEntry for the _value_. The access counter is set
    # to 1 to increase the chance that it is not flushed immedidate.
    def initialize(value)
      @value = value
      @hits = 1
    end

    # Return the value and increase the access counter by 1.
    def value
      if @hits <= 0
        @hits = 1
      else
        @hits += 1
      end
      @value
    end

  end

  # This class provides a global data cache that can be used to store and
  # retrieve values indexed by a key. The cache is size limited. When maximum
  # capacity is reached, a certain percentage of the least requested values is
  # dropped from the cache. The primary purpose of this global cache is to
  # store values that are expensive to compute but may be need on several
  # occasions during the program execution.
  class DataCache

    include Singleton

    def initialize
      resize
      flush
      # Counter for the number of writes to the cache.
      @stores = 0
      # Counter for the number of found values.
      @hits = 0
      # Counter for the number of not found values.
      @misses = 0
    end

    # For now, we use this randomly determined size.
    def resize(size = 100000)
      @highWaterMark = size
      # Flushing out the least used entries is fairly expensive. So we only
      # want to do this once in a while. The lowWaterMark determines how much
      # of the entries will survive the flush.
      @lowWaterMark = size * 0.9
    end

    # Completely flush the cache. The statistic counters will remain intact,
    # but all data values are lost.
    def flush
      @entries = {}
    end

  if RUBY_VERSION < '1.9.0'

    # Ruby 1.8 has a buggy hash key generation algorithm that leads to many
    # hash collisions. We completely disable caching on 1.8.

    def cached(*args)
      yield
    end

  else

    # _args_ is a set of arguments that unambigously identify the data entry.
    # It's converted into a hash to store or recover a previously stored
    # entry. If we have a value for the key, return the value. Otherwise call the
    # block to compute the value, store it and return it.
    def cached(*args)
      key = args.hash
      if @entries.has_key?(key)
        e = @entries[key]
        @hits += 1
        e.value
      else
        @misses += 1
        store(yield, key)
      end
    end

  end

    def to_s
      <<"EOT"
Entries: #{@entries.size}   Stores: #{@stores}
Hits: #{@hits}   Misses: #{@misses}
Hit Rate: #{@hits * 100.0 / (@hits + @misses)}%
EOT
    end

    private

    # Store _value_ into the cache using _key_ to tag it. _key_ must be unique
    # and must be used to load the value from the cache again. You cannot
    # store nil values!
    def store(value, key)
      @stores += 1

      if @entries.size > @highWaterMark
        while @entries.size > @lowWaterMark
          # How many entries do we need to delete to get to the low watermark?
          toDelete = @entries.size - @lowWaterMark
          @entries.delete_if do |foo, e|
            # Hit counts age with every cleanup.
            (e.hits -= 1) < 0 && (toDelete -= 1) >= 0
          end
        end
      end

      @entries[key] = DataCacheEntry.new(value)

      value
    end

  end

end


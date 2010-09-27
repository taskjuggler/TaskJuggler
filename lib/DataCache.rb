#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = DataCache.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'time'
require 'singleton'

class TaskJuggler

  class DataCacheEntry

    attr_accessor :hits

    def initialize(value)
      @value = value
      @hits = 1
      @created = Time.new
    end

    def value
      @hits += 1
      @value
    end

  end

  class DataCache

    include Singleton

    def initialize(size = 100000)
      resize(size)
      @stores = 0
      @hits = 0
      @misses = 0
    end

    def resize(size)
      @entries = {}
      @highWaterMark = size
      @lowWaterMark = size * 0.9
    end

    def flush
      @entries = {}
    end

    def store(value, *args)
      @stores += 1
      # If the cache has reached the specified high water mark, we throw out
      # old values.
      if @entries.size > @highWaterMark
        #puts "Entries: #{@entries.size}  Stores: #{@stores}"
        #puts "Hits: #{@hits}  Misses: #{@misses}  " +
        #puts "Hit Rate: #{@hits * 100.0 / (@hits + @misses)}"

        while @entries.size > @lowWaterMark
          # How many entries do we need to delete to get to the low watermark?
          toDelete = @entries.size - @lowWaterMark
          @entries.delete_if do |key, e|
            # Hit counts age with every cleanup.
            (e.hits -= 1) < 0 && (toDelete -= 1) >= 0
          end
        end
      end

      @entries[args.hash] = DataCacheEntry.new(value)

      value
    end

    def load(*args)
      if (e = @entries[args.hash])
        @hits += 1
        e.value
      else
        @misses += 1
        nil
      end
    end

  end

end


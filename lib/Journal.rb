#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WorkingHours.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class JournalEntry

    attr_reader :date, :headline, :property
    attr_accessor :intro, :more

    def initialize(journal, date, headline, property)
      @journal = journal
      @journal.addEntry(self)
      @date = date
      @headline = headline
      @property = property
      @intro = nil
      @more = nil
    end

  end

  class Journal

    def initialize
      @entries = []
    end

    def addEntry(entry)
      @entries << entry
    end

  end

end

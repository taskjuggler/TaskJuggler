#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = ICalendar.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Tj3Config'

class TaskJuggler

  # This class implements a very basic RFC5546 compliant iCalendar file
  # generator. It currently only supports a very small subset of the tags that
  # are needed for TaskJuggler.
  class ICalendar

    # Stores the data of an VTODO record and can generate one.
    class Todo

      attr_accessor :description, :relatedTo, :priority, :percentComplete
      attr_reader :uid

      # Create the Todo object with some mandatory data. _ical_ is a reference
      # to the parent ICalendar object. _uid_ is a unique pattern used to
      # generate the UID tag. _summary_ is a String for SUMMARY. _startDate_
      # is used to generate DTSTART. _endDate_ is used to either generate
      # the COMPLETED or DUE tag.
      def initialize(ical, uid, summary, startDate, endDate)
        # Mandatory attributes
        @ical = ical
        @ical.addTodo(self)
        @uid = uid
        @summary = summary
        @startDate = startDate
        @endDate = endDate
        # Optional attributes
        @description = nil
        @relatedTo = nil
        @priority = 1
        @percentComplete = -1
      end

      # Generate the VTODO record as String.
      def to_s
        str = <<"EOT"
BEGIN:VTODO
DTSTAMP:#{@ical.dateToRFC(TjTime.new.utc)}
CREATED:#{@ical.dateToRFC(TjTime.new.utc)}
UID: #{@uid}
LAST-MODIFIED:#{@ical.dateToRFC(TjTime.new.utc)}
SUMMARY:#{@summary}
PRIORITY:#{@priority}
DTSTART:#{@ical.dateToRFC(@startDate)}
EOT
         str += "DESCRIPTION:#{@description}\n" if @description
         str += "RELATED-TO:#{@relatedTo}\n" if @relatedTo

         if @percentComplete < 0
           str += "DUE:#{@ical.dateToRFC(@endDate)}\n"
         else
           str += "COMPLETED:#{@ical.dateToRFC(@completed)}\n"
         end
         str += <<"EOT"
PERCENT-COMPLETE:#{@percentComplete}
END:VTODO

EOT
         str
      end

    end

    # Stores the data of an VTODO record and can generate one.
    class Event

      attr_accessor :description

      # Create the Event object with some mandatory data. _ical_ is a
      # reference to the parent ICalendar object. _uid_ is a unique pattern
      # used to generate the UID tag. _summary_ is a String for SUMMARY.
      # _startDate_ is used to generate DTSTART. _endDate_ is used to either
      # generate the COMPLETED or DUE tag.
      def initialize(ical, uid, summary, startDate, endDate)
        # Mandatory attributes
        @ical = ical
        @ical.addEvent(self)
        @uid = uid
        @summary = summary
        @startDate = startDate
        @endDate = endDate
        # Optional attributes
        @description = nil
        @priority = 1
        @percentComplete = -1
      end

      # Generate the VEVENT record as String.
      def to_s
        str = <<"EOT"
BEGIN:VEVENT
DTSTAMP:#{@ical.dateToRFC(TjTime.new.utc)}
CREATED:#{@ical.dateToRFC(TjTime.new.utc)}
UID: #{@uid}
LAST-MODIFIED:#{@ical.dateToRFC(TjTime.new.utc)}
SUMMARY:#{@summary}
PRIORITY:#{@priority}
DTSTART:#{@ical.dateToRFC(@startDate)}
DTEND:#{@ical.dateToRFC(@endDate)}
EOT
         if @description
           str += "DESCRIPTION:#{@description}\n"
         end
         str += <<"EOT"
TRANSP:TRANSPARENT
END:VEVENT

EOT
         str
      end

    end

    attr_reader :uid

    def initialize(uid)
      @uid = uid
      @todos = []
      @events = []
    end

    def addTodo(todo)
      @todos << todo
    end

    def addEvent(event)
      @events << event
    end

    def to_s
      str = <<"EOT"
BEGIN:VCALENDAR
PRODID:-//#{AppConfig.softwareName}/#{AppConfig.packageName} #{AppConfig.version}//EN
VERSION:2.0
EOT
      @todos.each { |todo| str += todo.to_s }
      @events.each { |event| str += event.to_s }

      str << <<"EOT"
END:VCALENDAR
EOT

      # Convert all '\n' to '\r\n'
      str.gsub(/\n/, "\r\n")
    end

    def dateToRFC(date)
      date.to_s("%Y%m%dT%H%M%SZ")
    end

  end

end


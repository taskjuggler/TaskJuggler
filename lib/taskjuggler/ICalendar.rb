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

  # This class implements a very basic RFC5545 compliant iCalendar file
  # generator. It currently only supports a very small subset of the tags that
  # are needed for TaskJuggler.
  class ICalendar

    # The maximum allowed length of a content line without line end character.
    LINELENGTH = 75

    class Person < Struct.new(:name, :email)
    end

    # Base class for all ICalendar components.
    class Component

      attr_accessor :description, :relatedTo, :organizer

      def initialize(ical, uid, summary, startDate)
        @ical = ical
        @uid = uid
        @summary = summary
        @startDate = startDate

        # Optional attributes
        @description = nil
        @relatedTo = nil
        @organizer = nil
        @attendees = []
      end

      def setOrganizer(name, email)
        @organizer = Person.new(name, email)
      end

      def addAttendee(name, email)
        @attendees << Person.new(name, email)
      end

      def to_s
        str = <<"EOT"
DTSTAMP:#{dateTime(TjTime.new.utc)}
CREATED:#{dateTime(@ical.creationDate)}
UID:#{@uid}
LAST-MODIFIED:#{dateTime(@ical.lastModified)}
SUMMARY:#{quoted(@summary)}
DTSTART:#{dateTime(@startDate)}
EOT
        str += "DESCRIPTION:#{quoted(@description)}\n" if @description
        str += "RELATED-TO:#{@relatedTo}\n" if @relatedTo

        if @organizer
          str += "ORGANIZER;CN=#{@organizer.name}:mailto:#{@organizer.email}\n"
        end
        @attendees.each do |attendee|
          str += "ATTENDEE;CN=#{attendee.name}:mailto:#{attendee.email}\n"
        end

        str
      end

      private

      def dateTime(date)
        @ical.dateTime(date)
      end

      def quoted(str)
        str.gsub(/([;,"\\])/, '\\\\\1').gsub(/\n/, '\n')
      end

    end

    # Stores the data of an VTODO component and can generate one.
    class Todo < Component

      attr_accessor :priority, :percentComplete
      attr_reader :uid

      # Create the Todo object with some mandatory data. _ical_ is a reference
      # to the parent ICalendar object. _uid_ is a unique pattern used to
      # generate the UID tag. _summary_ is a String for SUMMARY. _startDate_
      # is used to generate DTSTART. _endDate_ is used to either generate
      # the COMPLETED or DUE tag.
      def initialize(ical, uid, summary, startDate, endDate)
        super(ical, uid, summary, startDate)

        # Mandatory attributes
        @ical.addTodo(self)
        @endDate = endDate
        # Priority value (0 - 9)
        @priority = 0
        @percentComplete = -1
      end

      # Generate the VTODO record as String.
      def to_s
        str = "BEGIN:VTODO\n"
        str += super
        if @percentComplete < 100.0
          str += "DUE:#{dateTime(@endDate)}\n"
        else
          str += "COMPLETED:#{dateTime(@endDate)}\n"
        end
        str += <<"EOT"
PERCENT-COMPLETE:#{@percentComplete}
END:VTODO

EOT
        str
      end

    end

    # Stores the data of an VTODO component and can generate one.
    class Event < Component

      # Create the Event object with some mandatory data. _ical_ is a
      # reference to the parent ICalendar object. _uid_ is a unique pattern
      # used to generate the UID tag. _summary_ is a String for SUMMARY.
      # _startDate_ is used to generate DTSTART. _endDate_ is used to either
      # generate the COMPLETED or DUE tag.
      def initialize(ical, uid, summary, startDate, endDate)
        super(ical, uid, summary, startDate)
        @ical.addEvent(self)

        # Mandatory attributes
        @endDate = endDate
        # Optional attributes
        @priority = 1
      end

      # Generate the VEVENT record as String.
      def to_s
        str = "BEGIN:VEVENT\n"
        str += super
        str += <<"EOT"
PRIORITY:#{@priority}
DTEND:#{dateTime(@endDate)}
TRANSP:TRANSPARENT
END:VEVENT

EOT
         str
      end

    end

    attr_reader :uid
    attr_accessor :creationDate, :lastModified

    def initialize(uid)
      @uid = "#{AppConfig.packageName}-#{uid}"
      @creationDate = @lastModified = TjTime.new.utc

      @todos = []
      @events = []
    end

    # Add a now VTODO component. For internal use only!
    def addTodo(todo)
      @todos << todo
    end

    # Add a now VEVENT component. For internal use only!
    def addEvent(event)
      @events << event
    end

    def to_s
      str = <<"EOT"
BEGIN:VCALENDAR
PRODID:-//The #{AppConfig.softwareName} Project/NONSGML #{AppConfig.softwareName} #{AppConfig.version}//EN
VERSION:2.0

EOT
      @todos.each { |todo| str += todo.to_s }
      @events.each { |event| str += event.to_s }

      str << <<"EOT"
END:VCALENDAR
EOT

      foldLines(str)
    end

    def dateTime(date)
      date.to_s("%Y%m%dT%H%M%SZ")
    end

    private

    # Make sure that no line is longer than LINELENTH octets (excl. the
    # newline character)
    def foldLines(str)
      newStr = ''
      str.each_line do |line|
        bytes = 0
        line.each_utf8_char do |c|
          # Make sure we support Ruby 1.8 and 1.9 String handling.
          cBytes = c.bytesize
          if bytes + cBytes > LINELENGTH && c != "\n"
            newStr += "\n "
            bytes = 0
          else
            bytes += cBytes
          end
          newStr << c
        end
      end
      # Convert line ends to CR+LF
      newStr.gsub(/\n/, "\r\n")
    end

  end

end


#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Attributes.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/Allocation'
require 'taskjuggler/AttributeBase'
require 'taskjuggler/Charge'
require 'taskjuggler/ChargeSet'
require 'taskjuggler/Limits'
require 'taskjuggler/LogicalOperation'
require 'taskjuggler/ShiftAssignments'
require 'taskjuggler/WorkingHours'

class TaskJuggler

  class AccountAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def AccountAttribute::tjpId
      'account'
    end

    def to_s(query = nil)
      @value ? @value.id : ''
    end

    def to_tjp
      @value ? @value.id : ''
    end

  end

  class AllocationAttribute < AttributeBase
    def initialize(property, type)
      super

      @value = Array.new
    end

    def AllocationAttribute::tjpId
      'allocation'
    end

    def to_tjp
      out = []
      @value.each do |allocation|
        out.push("allocate #{allocation.to_tjp}\n")
        # TODO: incomplete
      end
      out
    end

    def to_s(query = nil)
      out = ''
      first = true
      @value.each do |allocation|
        if first
          first = false
        else
          out << "\n"
        end
        out << '[ '
        firstR = true
        allocation.candidates.each do |resource|
          if firstR
            firstR = false
          else
            out << ', '
          end
          out << resource.fullId
        end
        modes = %w(order lowprob lowload hiload random)
        out << " ] select by #{modes[allocation.selectionMode]} "
        out << 'mandatory ' if allocation.mandatory
        out << 'persistent ' if allocation.persistent
      end
      out
    end

  end

  class BookingListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def BookingListAttribute::tjpId
      'bookinglist'
    end

    def to_s(query = nil)
      @value.collect{ |x| x.to_s }.join(', ')
    end

    def to_tjp
      raise "Don't call this method. This needs to be a special case."
    end

  end

  class BooleanAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def BooleanAttribute::tjpId
      'boolean'
    end

    def to_s(query = nil)
      @value ? 'true' : 'false'
    end

    def to_tjp
      @type.id + ' ' + (@value ? 'yes' : 'no')
    end

  end

  class ChargeListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def ChargeListAttribute::tjpId
      'charge'
    end

    def to_s(query = nil)
      @value.join(', ')
    end

  end

  # A ChargeSetListAttribute encapsulates a list of ChargeSet objects as
  # PropertyTreeNode attributes.
  class ChargeSetListAttribute < ListAttributeBase

    def initialize(property, type)
      super
    end

    def ChargeSetListAttribute::tjpId
      'chargeset'
    end

    def to_s(query = nil)
      out = []
      @value.each { |i| out << i.to_s }
      out.join(", ")
    end

    def to_tjp
      out = []
      @value.each { |i| out << i.to_s }
      @type.id + " " + out.join(', ')
    end

  end

  class ColumnListAttribute < ListAttributeBase

    def initialize(property, type)
      super
    end

    def ColumnListAttribute::tjpId
      'columns'
    end

    def to_s(query = nil)
      "TODO"
    end
  end

  class DateAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def to_s(query = nil)
      if @value
        @value.to_s(query ? query.timeFormat : '%Y-%m-%d')
      else
        'Error'
      end
    end

    def DateAttribute::tjpId
      'date'
    end
  end

  class DefinitionListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end
  end

  class DependencyListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def DependencyListAttribute::tjpId
      'dependencylist'
    end

    def to_s(query = nil)
      out = []
      @value.each { |t| out << t.task.fullId if t.task }
      out.join(', ')
    end

    def to_tjp
      out = []
      @value.each { |taskDep| out << taskDep.task.fullId }
      @type.id + " " + out.join(', ')
    end

  end

  class DurationAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def DurationAttribute::tjpId
      'duration'
    end

    def to_tjp
      @type.id + ' ' + @value.to_s + 'h'
    end

    def to_s(query = nil)
      query ? query.scaleDuration(query.project.slotsToDays(@value)) :
              @value.to_s
    end

  end

  class FixnumAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def FixnumAttribute::tjpId
      'integer'
    end
  end

  class FlagListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def FlagListAttribute::tjpId
      'flaglist'
    end

    def to_s(query = nil)
      @value.join(', ')
    end

    def to_tjp
      "flags #{@value.join(', ')}"
    end

  end

  class FloatAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def FloatAttribute::tjpId
      'float'
    end

    def to_tjp
      id + ' ' + @value.to_s
    end

  end

  class FormatListAttribute < ListAttributeBase

    def initialize(property, type)
      super
    end

    def to_s(query = nil)
      @value.join(', ')
    end

  end

  class IntervalListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def IntervalListAttribute::tjpId
      'intervallist'
    end

    def to_s(query = nil)
      out = []
      @value.each { |i| out << i.to_s }
      out.join(", ")
    end

    def to_tjp
      out = []
      @value.each { |i| out << i.to_s }
      @type.id + " " + out.join(', ')
    end

  end

  class LimitsAttribute < AttributeBase

    def initialize(property, type)
      super
      @value.setProject(property.project) if @value
    end

    def LimitsAttribute::tjpId
      'limits'
    end

    def to_tjp
      'This code is still missing!'
    end

  end

  class LogicalExpressionAttribute < AttributeBase

    def initialize(property, type)
      super
    end

    def LogicalExpressionAttribute::tjpId
      'logicalexpressions'
    end

  end

  class LogicalExpressionListAttribute < ListAttributeBase

    def initialize(property, type)
      super
    end

    def LogicalExpressionListAttribute::tjpId
      'logicalexpressions'
    end

  end

  class NodeListAttribute < ListAttributeBase
    def initialize(propery, type)
      super
    end
  end

  class PropertyAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def PropertyAttribute::tjpId
      'property'
    end
  end

  class RealFormatAttribute < AttributeBase

    def initialize(property, type)
      super
    end

  end

  class ReferenceAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def ReferenceAttribute::tjpId
      'reference'
    end

    def to_s(query)
      url || ''
    end

    def to_rti(query)
      return nil unless @value

      rText = RichText.new("[#{url} #{label}]")
      rText.generateIntermediateFormat
    end

    def to_tjp
      "#{@type.id} \"#{url}\"#{label ? " { label \"#{label}\" }" : ''}"
    end

    def url
      @value ? @value[0] : nil
    end

    def label
      @value ? (@value[1] ? @value[1][0] : @value[0]) : nil
    end

  end

  class ResourceListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def ResourceListAttribute::tjpId
      'resourcelist'
    end

    def to_s(query = nil)
      out = []
      @value.each { |r| out << r.fullId }
      out.join(", ")
    end

    def to_rti(query = nil)
      out = []
      if query
        @value.each do |r|
          if query.listItem
            rti = RichText.new(query.listItem, RTFHandlers.create(r.project),
                               r.project.messageHandler).
                               generateIntermediateFormat
            q = query.dup
            q.property = r
            rti.setQuery(q)
            out << "<nowiki>#{rti.to_s}</nowiki>"
          else
            out << "<nowiki>#{r.name}</nowiki>"
          end
        end
        query.assignList(out)
      else
        @value.each { |r| out << r.name }
        rText = RichText.new(out.join(', '))
        rText.generateIntermediateFormat
      end
    end

    def to_tjp
      out = []
      @value.each { |r| out << r.fullId }
      @type.id + " " + out.join(', ')
    end

  end

  class RichTextAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def inputText
      @value ? @value.richText.inputText : ''
    end

    def RichTextAttribute::tjpId
      'richtext'
    end

    def to_s(query = nil)
      @value ? @value.to_s : ''
    end

    def to_tjp
      inputText = @value.richText.inputText
      if inputText[-1] == ?\n
        "#{@type.id} -8<-\n#{inputText}\n->8-"
      else
        escaped = inputText.gsub("\"", '\"')
        "#{@type.id} \"#{escaped}\""
      end
    end

  end

  class ScenarioListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def ScenarioListAttribute::tjpId
      'scenarios'
    end

    def to_s(query = nil)
      @value.join(', ')
    end

  end


  class ShiftAssignmentsAttribute < AttributeBase

    def initialize(property, type)
      super
      @value.project = property.project if @value
    end

    def ShiftAssignmentsAttribute::tjpId
      'shifts'
    end

    def to_tjp
      'This code is still missing!'
    end

  end

  class SortListAttribute < ListAttributeBase

    def initialize(property, type)
      super
    end

    def SortListAttribute::tjpId
      'sorting'
    end

  end

  class StringAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def StringAttribute::tjpId
      'text'
    end

    def to_tjp
      "#{@type.id} \"#{@value}\""
    end

  end

  class SymbolAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def SymbolAttribute::tjpId
      'symbol'
    end
  end

  class TaskDepListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def TaskDepListAttribute::tjpId
      'taskdeplist'
    end

    def to_s(query = nil)
      out = []
      @value.each { |t, onEnd| out << t.fullId }
      out.join(", ")
    end

    def to_tjp
      out = []
      @value.each { |t, onEnd| out << t.fullId }
      @type.id + " " + out.join(', ')
    end
  end

  class TaskListAttribute < ListAttributeBase
    def initialize(property, type)
      super
    end

    def TaskListAttribute::tjpId
      'tasklist'
    end

    def to_s(query = nil)
      out = []
      @value.each { |t| out << t.fullId }
      out.join(", ")
    end

    def to_tjp
      out = []
      @value.each { |t| out << t.fullId }
      @type.id + " " + out.join(', ')
    end
  end

  class WorkingHoursAttribute < AttributeBase
    def initialize(property, type)
      super
    end

    def WorkingHoursAttribute::tjpId
      'workinghours'
    end

    def to_tjp
      dayNames = %w( sun mon tue wed thu fri sat )
      str = ''
      7.times do |day|
        str += "workinghours #{dayNames[day]} "
        whs = @value.getWorkingHours(day)
        if whs.empty?
          str += "off"
          str += "\n" if day < 6
          next
        end
        first = true
        whs.each do |iv|
          if first
            first = false
          else
            str += ', '
          end
          str += "#{iv[0] / 3600}:#{iv[0] % 3600 == 0 ?
                                    '00' : iv[0] % 3600} - " +
                 "#{iv[1] / 3600}:#{iv[1] % 3600 == 0 ? '00' : iv[1] % 3600}"
        end
        str += "\n" if day < 6
      end
      str
    end

  end

end


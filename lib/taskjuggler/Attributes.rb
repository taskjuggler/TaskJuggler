#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Attributes.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
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
    def initialize(property, type, container)
      super
    end

    def AccountAttribute::tjpId
      'account'
    end

    def to_s(query = nil)
      (v = get) ? v.id : ''
    end

    def to_tjp
      (v = get)? v.id : ''
    end

  end

  class AccountCreditListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super

      set(Array.new)
    end

    def AccountCreditListAttribute::tjpId
      'credits'
    end

  end

  class AllocationAttribute < ListAttributeBase
    def initialize(property, type, container)
      super

      set(Array.new)
    end

    def AllocationAttribute::tjpId
      'allocation'
    end

    def to_tjp
      out = []
      get.each do |allocation|
        out.push("allocate #{allocation.to_tjp}\n")
        # TODO: incomplete
      end
      out
    end

    def to_s(query = nil)
      out = ''
      first = true
      get.each do |allocation|
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
    def initialize(property, type, container)
      super
    end

    def BookingListAttribute::tjpId
      'bookinglist'
    end

    def to_s(query = nil)
      get.collect{ |x| x.to_s }.join(', ')
    end

    def to_tjp
      raise "Don't call this method. This needs to be a special case."
    end

  end

  class BooleanAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def BooleanAttribute::tjpId
      'boolean'
    end

    def to_s(query = nil)
      get ? 'true' : 'false'
    end

    def to_tjp
      @type.id + ' ' + (get ? 'yes' : 'no')
    end

  end

  class ChargeListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def ChargeListAttribute::tjpId
      'charge'
    end

    def to_s(query = nil)
      get.join(', ')
    end

  end

  # A ChargeSetListAttribute encapsulates a list of ChargeSet objects as
  # PropertyTreeNode attributes.
  class ChargeSetListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

    def ChargeSetListAttribute::tjpId
      'chargeset'
    end

    def to_s(query = nil)
      out = []
      get.each { |i| out << i.to_s }
      out.join(", ")
    end

    def to_tjp
      out = []
      get.each { |i| out << i.to_s }
      @type.id + " " + out.join(', ')
    end

  end

  class ColumnListAttribute < ListAttributeBase

    def initialize(property, type, container)
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
    def initialize(property, type, container)
      super
    end

    def to_s(query = nil)
      if (v = get)
        v.to_s(query ? query.timeFormat : '%Y-%m-%d')
      else
        'Error'
      end
    end

    def DateAttribute::tjpId
      'date'
    end
  end

  class DefinitionListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end
  end

  class DependencyListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def DependencyListAttribute::tjpId
      'dependencylist'
    end

    def to_s(query = nil)
      out = []
      get.each { |t| out << t.task.fullId if t.task }
      out.join(', ')
    end

    def to_tjp
      out = []
      get.each { |taskDep| out << taskDep.task.fullId }
      @type.id + " " + out.join(', ')
    end

  end

  class DurationAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def DurationAttribute::tjpId
      'duration'
    end

    def to_tjp
      @type.id + ' ' + get.to_s + 'h'
    end

    def to_s(query = nil)
      query ? query.scaleDuration(query.project.slotsToDays(get)) :
              get.to_s
    end

  end

  class IntegerAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def IntegerAttribute::tjpId
      'integer'
    end
  end

  class FlagListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def FlagListAttribute::tjpId
      'flaglist'
    end

    def to_s(query = nil)
      get.join(', ')
    end

    def to_tjp
      "flags #{get.join(', ')}"
    end

  end

  class FloatAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def FloatAttribute::tjpId
      'number'
    end

    def to_tjp
      id + ' ' + get.to_s
    end

  end

  class FormatListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

    def to_s(query = nil)
      get.join(', ')
    end

  end

  class JournalSortListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

    def JournalSortListAttribute::tjpId
      'journalsorting'
    end

  end

  class TimeIntervalListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def TimeIntervalListAttribute::tjpId
      'intervallist'
    end

    def to_s(query = nil)
      out = []
      get.each { |i| out << i.to_s }
      out.join(", ")
    end

    def to_tjp
      out = []
      get.each { |i| out << i.to_s }
      @type.id + " " + out.join(', ')
    end

  end

  class LeaveAllowanceListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

  end

  class LeaveListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

    def LeaveListAttribute::tjpId
      'leave'
    end

    def to_tjp
      "leaves #{get.join(",\n")}"
    end

  end

  class LimitsAttribute < AttributeBase

    def initialize(property, type, container)
      super
      v = get
      v.setProject(property.project) if v
    end

    def LimitsAttribute::tjpId
      'limits'
    end

    def to_tjp
      'This code is still missing!'
    end

  end

  class LogicalExpressionAttribute < AttributeBase

    def initialize(property, type, container)
      super
    end

    def LogicalExpressionAttribute::tjpId
      'logicalexpressions'
    end

  end

  class LogicalExpressionListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

    def LogicalExpressionListAttribute::tjpId
      'logicalexpressions'
    end

  end

  class NodeListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end
  end

  class PropertyAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def PropertyAttribute::tjpId
      'property'
    end
  end

  class RealFormatAttribute < AttributeBase

    def initialize(property, type, container)
      super
    end

  end

  class ReferenceAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def ReferenceAttribute::tjpId
      'reference'
    end

    def to_s(query = nil)
      url || ''
    end

    def to_rti(query)
      return nil unless get

      rText = RichText.new("[#{url} #{label}]")
      rText.generateIntermediateFormat
    end

    def to_tjp
      "#{@type.id} \"#{url}\"#{label ? " { label \"#{label}\" }" : ''}"
    end

    def url
      (v = get) ? v[0] : nil
    end

    def label
      (v = get) ? (v[1] ? v[1][0] : v[0]) : nil
    end

  end

  class ResourceListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def ResourceListAttribute::tjpId
      'resourcelist'
    end

    def to_s(query = nil)
      out = []
      get.each { |r| out << r.fullId }
      out.join(", ")
    end

    def to_rti(query = nil)
      out = []
      if query
        get.each do |r|
          if query.listItem
            rti = RichText.new(query.listItem, RTFHandlers.create(r.project)).
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
        get.each { |r| out << r.name }
        rText = RichText.new(out.join(', '))
        rText.generateIntermediateFormat
      end
    end

    def to_tjp
      out = []
      get.each { |r| out << r.fullId }
      @type.id + " " + out.join(', ')
    end

  end

  class RichTextAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def inputText
      (v = get) ? v.richText.inputText : ''
    end

    def RichTextAttribute::tjpId
      'richtext'
    end

    def to_s(query = nil)
      (v = get) ? v.to_s : ''
    end

    def to_tjp
      "#{@type.id} #{quotedString(get.richText.inputText)}"
    end

  end

  class ScenarioListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def ScenarioListAttribute::tjpId
      'scenarios'
    end

    def to_s(query = nil)
      get.join(', ')
    end

  end


  class ShiftAssignmentsAttribute < AttributeBase

    def initialize(property, type, container)
      super
      v = get
      v.project = property.project if v
    end

    def ShiftAssignmentsAttribute::tjpId
      'shifts'
    end

    def to_tjp
      v = get
      first = true
      str = 'shifts '
      v.assignments.each do |sa|
        if first
          first = false
        else
          str += ",\n"
        end

        str += "#{sa.shiftScenario.property.fullId} #{sa.interval}"
      end

      str
    end

  end

  class SortListAttribute < ListAttributeBase

    def initialize(property, type, container)
      super
    end

    def SortListAttribute::tjpId
      'sorting'
    end

  end

  class StringAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def StringAttribute::tjpId
      'text'
    end

    def to_tjp
      "#{@type.id} #{quotedString(get)}"
    end

  end

  class SymbolAttribute < AttributeBase
    def initialize(property, type, container)
      super
    end

    def SymbolAttribute::tjpId
      'symbol'
    end
  end

  class SymbolListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def SymbolListAttribute::tjpId
      'symbollist'
    end
  end

  class TaskDepListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def TaskDepListAttribute::tjpId
      'taskdeplist'
    end

    def to_s(query = nil)
      out = []
      get.each { |t, onEnd| out << t.fullId }
      out.join(", ")
    end

    def to_tjp
      out = []
      get.each { |t, onEnd| out << t.fullId }
      @type.id + " " + out.join(', ')
    end
  end

  class TaskListAttribute < ListAttributeBase
    def initialize(property, type, container)
      super
    end

    def TaskListAttribute::tjpId
      'tasklist'
    end

    def to_s(query = nil)
      out = []
      get.each { |t| out << t.fullId }
      out.join(", ")
    end

    def to_tjp
      out = []
      get.each { |t| out << t.fullId }
      @type.id + " " + out.join(', ')
    end
  end

  class WorkingHoursAttribute < AttributeBase
    def initialize(property, type, container)
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
        whs = get.getWorkingHours(day)
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
                                    '00' : (iv[0] % 3600) / 60} - " +
                 "#{iv[1] / 3600}:#{iv[1] % 3600 == 0 ?
                                    '00' : (iv[1] % 3600) / 60}"
        end
        str += "\n" if day < 6
      end
      str
    end

  end

end


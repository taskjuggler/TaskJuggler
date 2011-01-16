#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = IntervalList.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'Interval'

class TaskJuggler

  # A list of Intervals. The intervals in the list must not overlap and must
  # be in ascending order.
  class IntervalList < Array

    alias append <<

    def &(list)
      res = IntervalList.new
      si = li = 0
      while si < length && li < list.length do
        if self[si].start < list[li].start
          # The current Interval of self starts earlier than the current
          # Interval of list.
          if self[si].end <= list[li].start
            # self[si] does not overlap with list[li]. Ignore it.
            si += 1
          elsif self[si].end < list[li].end
            # self[si] does overlap with list[li] but list[li] goes further
            res << Interval.new(list[li].start, self[si].end)
            si += 1
          else
            # self[si] does overlap with list[li] but self[si] goes further
            res << Interval.new(list[li].start, list[li].end)
            li += 1
          end
        elsif list[li].start < self[si].start
          # The current Interval of list starts earlier than the current
          # Interval of self.
          if list[li].end <= self[si].start
            # list[li] does not overlap with self[si]. Ignore it.
            li += 1
          elsif list[li].end < self[si].end
            # list[li] does overlap with self[si] but self[si] goes further
            res << Interval.new(self[si].start, list[li].end)
            li += 1
          else
            # list[li] does overlap with self[si] but list[li] goes further
            res << Interval.new(self[si].start, self[si].end)
            si += 1
          end
        else
          # self[si].start and list[li].start are identical
          if self[si].end == list[li].end
            # self[si] and list[li] are identical. Add the Interval and
            # increase both pointers.
            res << self[si]
            li += 1
            si += 1
          elsif self[si].end < list[li].end
            # self[si] ends earlier.
            res << self[si]
            si += 1
          else
            # list[li] ends earlier.
            res << list[li]
            li += 1
          end
        end
      end

      res
    end

    # Append the Interval _iv_. If the start of _iv_ matches the end of the
    # list list item, _iv_ is merged with the last item.
    def <<(iv)
      if last
        if last.end > iv.start
          raise "Intervals may not overlap and must be added in " +
                "ascending order."
        elsif last.end == iv.start
          self[-1] = Interval.new(last.start, iv.end)
          return self
        end
      end

      append(iv)
    end

  end

end


#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StdIoWrapper.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  module StdIoWrapper

    Results = Struct.new(:returnValue, :stdOut, :stdErr)

    def stdIoWrapper(stdIn = nil)
      oldStdOut = $stdout
      oldStdErr = $stderr
      $stdout = (out = StringIO.new)
      $stderr = (err = StringIO.new)

      if stdIn
        oldStdIn = $stdin
        $stdin = StringIO.new(stdIn)
      end
      begin
        res = yield
      ensure
        $stdout = oldStdOut
        $stderr = oldStdErr
        $stdin = oldStdIn if stdIn
      end
      Results.new(res, out.string, err.string)
    end

  end

end


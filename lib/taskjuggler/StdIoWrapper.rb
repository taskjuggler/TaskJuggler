#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = StdIoWrapper.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  # This module provides just one method to run the passed block. It will
  # capture all content that will be send to $stdout and $stderr by the block.
  # I can also feed the String provided by _stdIn_ to $stdin of the block.
  module StdIoWrapper

    Results = Struct.new(:returnValue, :stdOut, :stdErr)

    def stdIoWrapper(stdIn = nil)
      # Save the old $stdout and $stderr and replace them with StringIO
      # objects to capture the output.
      oldStdOut = $stdout
      oldStdErr = $stderr
      $stdout = (out = StringIO.new)
      $stderr = (err = StringIO.new)

      # If the caller provided a String to feed into $stdin, we replace that
      # as well.
      if stdIn
        oldStdIn = $stdin
        $stdin = StringIO.new(stdIn)
      end

      begin
        # Call the block with the hooked up IOs.
        res = yield
      rescue RuntimeError
        # Blocks that are called this way usually return 0 on success and 1 on
        # errors.
        res = 1
      ensure
        # Restore the stdio channels no matter what.
        $stdout = oldStdOut
        $stderr = oldStdErr
        $stdin = oldStdIn if stdIn
      end

      # Return the return value of the block and the $stdout and $stderr
      # captures.
      Results.new(res, out.string, err.string)
    end

  end

end


#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MessageHandler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

class TaskJuggler

  class MessageHandler

    attr_reader :messages, :errors

    def initialize(console = false)
      @messages = []
      @console = console

      @errors = 0
    end

    def send(message)
      @errors += 1 if message.level == 'error' || message.level == 'fatal'
      @messages << message
      if @console
        # The to_s call is necessary to support remote prints via DRb.
        $stderr.puts message.to_s
      end
    end

  end

end


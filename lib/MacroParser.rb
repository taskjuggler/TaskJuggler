#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = MacroParser.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'TextParser'
require 'MessageHandler'

class TaskJuggler

  # This class implements a mini parser for the macro calls. It will be called
  # from the same scanner that it uses to read the macro tokens.
  class MacroParser < TextParser

    def initialize(scanner, messageHandler)
      super()

      @scanner = scanner
      @messageHandler = messageHandler
      @variables = %w( ID STRING )

      initRules
    end

    def nextToken
      @scanner.nextToken
    end

    def returnToken(token)
      @scanner.returnToken(token)
    end

    def rule_macroArguments
      optional
      repeatable
      pattern(%w( $STRING ), Proc.new {
        @val[0]
      })
    end

    def rule_macroCall
      pattern(%w( _{ !relax $ID !macroArguments _} ), Proc.new {
        # When the ID is prefixed by a '?' the macro may be undefined and the
        # macro call is replaced by an empty string.
        unless @scanner.macroDefined?(@val[2])
          if @val[1].nil?
            error('undef_macro', "Macro #{@val[2]} is undefined")
          end
          nil
        else
          @scanner.expandMacro([ @val[2] ] + @val[3])
        end
      })
      pattern(%w( _( $ID _) ), lambda {
        ENV[@val[0]]
      })
    end

    def rule_relax
      optional
      pattern(%w( _? ), lambda {
        true
      })
    end

  end

end


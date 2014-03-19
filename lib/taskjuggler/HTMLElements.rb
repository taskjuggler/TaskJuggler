#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = HTMLElements.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014
#               by Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'taskjuggler/XMLElement'

class TaskJuggler

  module HTMLElements

    # A list of supported HTML tags.
    htmlTags = %w( a b body br code col colgroup div em frame frameset footer
                   h1 h2 h3 head html hr meta p pre table td title tr )
    # A list of HTML tags that are self-closing.
    closureTags = %w( area base basefont br hr input img link meta )

    # For every HTML tag, we generate a class with the equivalent uppercase
    # name. This class is derived off of XMLElement. This makes creating HTML
    # code a lot simpler. Instead of
    #   XMLElement.new('h1')
    # we now can write
    #   H1.new
    htmlTags.each do |tag|
      class_eval <<"EOT"
        class #{tag.upcase} < XMLElement

          def initialize(attrs = {}, &block)
            super("#{tag}", attrs, #{closureTags.include?(tag)})
          end

        end
EOT
    end

  end

end

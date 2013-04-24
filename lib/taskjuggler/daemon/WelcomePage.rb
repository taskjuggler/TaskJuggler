#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = WelcomePage.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'webrick'

require 'taskjuggler/Tj3Config'
require 'taskjuggler/HTMLDocument'

class TaskJuggler

  class WelcomePage < WEBrick::HTTPServlet::AbstractServlet

    def initialize(config, *options)
      super
    end

    def self.get_instance(config, options)
      self.new(config, *options)
    end

    def do_GET(req, res)
      @req = req
      @res = res
      begin
        generateWelcomePage
      #rescue
      end
    end

    private

    def generateWelcomePage()
      text = <<"EOT"
== Welcome to TaskJuggler ==
----

This is the welcome page of your TaskJuggler built-in web server.
To access your loaded TaskJuggler projects, click [/taskjuggler here].

If you are seeing this page instead of the site you expected, please contact
the administrator of the site involved. Try sending mail to
<webmaster@domain>.

Although this site is running the TaskJuggler software it almost certainly has
no other connection to the TaskJuggler project, so please do not send mail
about this site or its contents to the TaskJuggler authors. If you do, your
message will be ignored.

You can use the following links to learn more about TaskJuggler:

* [#{AppConfig.contact} The TaskJuggler web site]
* [#{AppConfig.contact+ "/tj3/manual/index.html"} User Manual]

----
#{AppConfig.softwareName} v#{AppConfig.version}
- Copyright (c) #{AppConfig.copyright.join(', ')}
by #{AppConfig.authors.join(', ')}
EOT

      rt = RichText.new(text)
      rti = rt.generateIntermediateFormat
      rti.sectionNumbers = false
      page = HTMLDocument.new
      page.generateHead("Welcome to TaskJuggler")
      page.html << rti.to_html
      @res['content-type'] = 'text/html'
      @res.body = page.to_s
    end

  end

end

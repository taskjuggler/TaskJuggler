open( 'README', 'w' ) { |fn| fn << "

= About {#{PROJECT_NAME}}[#{PROJECT_HOMEPAGE}]

#{PROJECT_NAME} is an Open Source project management software. Right
now it is just a prototype of what will become the next generation of
#{PROJECT_NAME[0..-5]}. If you are looking for a stable software to manage your
projects, use the 2.x series releases.

In contrast to the 2.x version #{PROJECT_NAME} should be easily
installable and usable on non Unix/Linux systems as well. If you
don't fear the command prompt and can handle a text editor you can
even use it on Windows and MacOS X.

= Copyright and License

#{PROJECT_NAME[0..-5]} is (c) 2006, 2007, 2008 by #{USER_NAME} <cs (at) kde (dot) org>

This program is free software; you can redistribute it and/or modify
it under the terms of {version 2 of the GNU General Public
License}[http://www.gnu.org/licenses/old-licenses/gpl-2.0.html] as
published by the Free Software Foundation. You accept the terms of
this license by distributing or using this software.

#{PROJECT_NAME[0..-5]}[#{PROJECT_HOMEPAGE}] is a trademark of Chris Schlaeger.

= Installation

#{PROJECT_NAME} is written in Ruby[http://www.ruby-lang.org]. It
should run on any platform that Ruby is available on. It uses the
standard Ruby mechanism for distribution. The package format is called {Ruby
Gems}[http://docs.rubygems.org]. Alternatively, you can install from a
the source code using setup.rb.

This is a prototype. Consider it being alpha quality at best!

== Requirements 

Ruby applications are platform independent. There is no need to
compile anything. But #{PROJECT_NAME[0..-5]} has a very small set of
dependencies that you have to take care of first. Please make sure you
have the minimum required version installed.

[*Ruby*] #{PROJECT_NAME} is written in Ruby.  You need a Ruby runtime
	 environment to run it. This can be downloaded from
	 here[http://www.ruby-lang.org/en/downloads/].  Most Linux
	 distributions usually have Ruby already included. So does
	 MacOS X Leopard. For Windows, there is a one-click installer
	 available.  #{PROJECT_NAME[0..-5]}[#{PROJECT_HOMEPAGE}] currently
	 needs at least Ruby version 1.8.5.

[*RubyGems*] If it did not come with your OS or Ruby package, see
	     here[http://docs.rubygems.org] how to get and install it.

[*Rake*] Rake[http://rake.rubyforge.org] is only needed when you
	 start with the source code from the Git repository. It's not
	 needed when you already have a Gem package.

[*#{PROJECT_NAME[0..-5]}*] Get #{PROJECT_NAME} from the
                {Download Page}[#{PROJECT_HOMEPAGE}/download.php]

== Installation Process

If you have checked-out the git repository, you need to build the Gem
package first.

<tt>cd #{UNIX_NAME}; ./makedist</tt>

To install the Gem package, just run as root the following command.

<tt>gem install pkg/#{UNIX_NAME}-#{PROJECT_VERSION}.gem</tt> 

It will install all components of the Gem in the appropriate place.

== Update from previous versions

Updates work just like the installation.

<tt>gem update pkg/#{UNIX_NAME}-#{PROJECT_VERSION}.gem</tt>

= Using #{PROJECT_NAME}

The user manual can be found in folder data/manual of the Gem file or
at the {#{PROJECT_NAME[0..-5]} Web Site}[#{PROJECT_HOMEPAGE}/tj3/manual/index.html].

= Understanding the source code

Ruby code is usually pretty readable even if you don't know Ruby yet.
Additionally, we have tried to document all critical parts of the
code well enough for other people to understand the code. When
browsing the code you should start with the file
#{UNIX_NAME}.rb and the class #{PROJECT_NAME[0..-5]}.
"
}


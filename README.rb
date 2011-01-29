open( 'README', 'w' ) { |fn| fn << "

= About {#{PROJECT_NAME}}[#{PROJECT_HOMEPAGE}]

#{PROJECT_NAME} is an Open Source project management software. Right
now it is just a prototype of what will become the next generation of
#{PROJECT_NAME[0..-5]}. If you are looking for a stable software to manage your
projects, use the 2.x series releases.

In contrast to the 2.x version #{PROJECT_NAME} should be easily
installable and usable also on non Linux or Unix-like systems. It may sound
repelling at first, but this software does not need a graphical user
interface. A command shell, a plain text editor (no word processor!) and a web
browser is all you need.

= Copyright and License

#{PROJECT_NAME[0..-5]} is (c) 2006, 2007, 2008, 2009, 2010, 2011 by #{USER_NAME} <#{USER_EMAIL}>

This program is free software; you can redistribute it and/or modify
it under the terms of {version 2 of the GNU General Public
License}[http://www.gnu.org/licenses/old-licenses/gpl-2.0.html] as
published by the Free Software Foundation. You accept the terms of
this license by distributing or using this software.

#{PROJECT_NAME[0..-5]}[#{PROJECT_HOMEPAGE}] is a trademark of #{USER_NAME}.

= User Manual

The user manual can be found at the {#{PROJECT_NAME[0..-5]} Web
Site}[#{PROJECT_HOMEPAGE}/tj3/manual/index.html]. Please see the manual for all further information about installing and using the software.
"}


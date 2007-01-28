require 'rubygems'
Gem::manage_gems
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = 'tj3'
  s.version = '0.0.3'
  s.author = 'Chris Schlaeger'
  s.email = 'cs@kde.org'
  s.homepage = 'http://www.taskjuggler.org'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Project Management Software'
  s.required_ruby_version  = '>= 1.8.4'
  #s.requirements << 'qtruby'
  s.files = FileList[ 'lib/*.rb', 'lib/*.png', 'lib/*.jpg', \
                      'data/*', 'bin/*'].exclude('rdoc').to_a
  s.require_path = "lib"
  s.bindir = 'bin'
  s.executables << 'tj3'
  s.autorequire = 'taskjuggler'
  s.has_rdoc = true
  s.extra_rdoc_files = [ 'README' ]
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end


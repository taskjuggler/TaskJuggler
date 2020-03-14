# GEM TASK
require 'find'
require 'rubygems'
require 'rubygems/package'

CLOBBER.include "pkg/"

# Unfortunately Rake::GemPackageTest cannot deal with files that are generated
# by Rake targets. So we have to write our own packaging task.
desc 'Build the gem package'
task :gem => [:clobber] do
  Rake::Task[:vim].invoke
  Rake::Task[:manual].invoke
  Rake::Task[:changelog].invoke
  Rake::Task[:permissions].invoke
  Rake::Task[:help2man].invoke

  load 'taskjuggler.gemspec';

  # Build the gem file according to the loaded spec.
  if RUBY_VERSION >= "2.0.0"
    Gem::Package.build(GEM_SPEC)
  else
    Gem::Builder.new(GEM_SPEC).build
  end
  pkgBase = "#{GEM_SPEC.name}-#{GEM_SPEC.version}"
  # Create a pkg directory if it doesn't exist already.
  FileUtils.mkdir_p('pkg')
  # Move the gem file into the pkg directory.
  verbose(true) { FileUtils.mv("#{pkgBase}.gem", "pkg/#{pkgBase}.gem")}
  # Create a tar file with all files that are in the gem.
  FileUtils.rm_f("pkg/#{pkgBase}.tar")
  FileUtils.rm_f("pkg/#{pkgBase}.tar.gz")
  verbose(false) {GEM_SPEC.files.each { |f| `tar rf pkg/#{pkgBase}.tar "#{f}"` } }
  # And gzip the file.
  `gzip pkg/#{pkgBase}.tar`
end

desc 'Make sure all files and directories are readable'
task :permissions do
  # Find the bin and test directories relative to this file.
  baseDir = File.expand_path('..', File.dirname(__FILE__))

  execs = Dir.glob("#{baseDir}/bin/*") +
          Dir.glob("#{baseDir}/test/**/genrefs")

  Find.find(baseDir) do |f|
    # Ignore the whoke pkg directory as it may contain links to the other
    # directories.
    next if Regexp.new("#{baseDir}/pkg/*").match(f)

    FileUtils.chmod_R((FileTest.directory?(f) ||
                       execs.include?(f) ? 0755 : 0644), f)
  end
end

desc 'Run all tests and build scripts and create the gem package'
task :release do
  Rake::Task[:test].invoke
  Rake::Task[:spec].invoke
  Rake::Task[:rdoc].invoke
  Rake::Task[:gem].invoke
end


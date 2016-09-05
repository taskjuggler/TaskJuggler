# TASK MANUAL

require 'taskjuggler/apps/Tj3Man'

CLOBBER.include "manual/html/"

desc 'Generate User Manual'
task :manual do
  htmldir = 'manual/html'
  rm_rf htmldir if File.exists? htmldir
  mkdir_p htmldir
  # Make sure we can run 'rake manual' from all subdirs.
  ENV['TASKJUGGLER_DATA_PATH'] =
    Array.new(4) { |i| Dir.getwd + '/..' * i }.join(':')
  TaskJuggler::Tj3Man.new.main([ '-d', htmldir, '-m', '--silent' ])
end



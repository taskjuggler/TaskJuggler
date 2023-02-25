$:.unshift File.join(File.dirname(__FILE__))

# Add the lib directory to the search path if it isn't included already
lib = File.expand_path('../lib', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rake'
require 'rspec'
require 'rake/clean'
require 'bundler/gem_tasks'

Dir.glob( 'tasks/*.rake').each do |fn|
  begin
    load fn;
  rescue LoadError
    puts "#{fn.split('/')[1]} tasks unavailable: #{$!}"
  end
end

task :default  => [ :test ]

desc 'Run all unit and spec tests'
task :test => [ :unittest, :spec ]

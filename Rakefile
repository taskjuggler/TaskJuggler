$:.unshift File.join(File.dirname(__FILE__))

# Add the lib directory to the search path if it isn't included already
lib = File.expand_path('../lib', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rake/clean'

Dir.glob( 'tasks/*.rake').each do |fn|
  begin 
    load fn;
  rescue LoadError
    puts "#{fn.split('/')[1]} tasks unavailable: #{$!}"
  end
end

task :default  => [ :test ]
task :test => [ :unittest, :spec ]

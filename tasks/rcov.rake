
require 'rcov/rcovtask'

# RCOV TASK
Rcov::RcovTask.new do |t|
    t.output_dir = RCOV_DIR
    t.verbose = true
if RUBY_1_9
    t.ruby_opts = [ "-r tasks/rexml_fix_19" ]
else
    t.ruby_opts = [ "-r tasks/rexml_fix" ]
end
    t.rcov_opts = [ "--charset utf8", "-T", "-i ^test", "-i ^bin", "-i ^lib", "-x rcov.rb$"  ]
end


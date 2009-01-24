
require 'rcov/rcovtask'

# RCOV TASK
Rcov::RcovTask.new do |t|
    t.output_dir = RCOV_DIR
    t.verbose = true
    t.rcov_opts = [ "--charset utf8", "-T", "-i ^test", "-i ^bin", "-i ^lib", "-x rcov.rb$"  ]
end


if not RUBY_1_9
    require 'rcov/rcovtask'

    # RCOV TASK
    Rcov::RcovTask.new do |t|
        t.output_dir = RCOV_DIR
        t.verbose = true
        t.ruby_opts = [ "-r tasks/rexml_fix" ]
        t.rcov_opts = [ "--charset utf8", "-T", "-i ^test", "-i ^bin", "-i ^lib", "-x rcov.rb$"  ]
    end
end


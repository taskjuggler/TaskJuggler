require 'daemon/ProjectBroker'

RSpec.configure do |c|
  c.filter_run_excluding :ruby => lambda {|version|
    !(RUBY_VERSION.to_s =~ /^#{version.to_s}/)
  }
end

class TaskJuggler

  describe ProjectBroker do

    it "can be started and stopped", :ruby => 1.9 do
      @pb = ProjectBroker.new
      @pb.authKey = 'secret'
      @pb.daemonize = false
      @pb.port = 0
      t = Thread.new { @pb.start }
      @pb.stop
      t.join
    end

  end

end

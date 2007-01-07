class TjException < RuntimeError

  attr_reader :error, :fatal

  def initialize(error = true, fatal = false)
    @error = error
    @fatal = fatal
  end

end


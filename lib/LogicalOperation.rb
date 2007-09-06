#
# LogicalOperation.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class LogicalOperation

  attr_reader :operand1
  attr_accessor :operand2, :operator

  def initialize(opnd1)
    @operand1 = opnd1
    @operand2 = nil
    @operator = nil
    @isAFlag = false
  end

  def eval(expr)
    begin
      case @operator
      when nil
        if @operand1.is_a?(LogicalOperation)
          return @operand1.eval(expr)
        else
          return @operand1 != 0
        end
      when '~'
        return !@operand1.eval(expr)
      when '>'
        return @operand1.eval(expr) > @operand2.eval(expr)
      when '>='
        return @operand1.eval(expr) >= @operand2.eval(expr)
      when '='
        return @operand1.eval(expr) == @operand2.eval(expr)
      when '<'
        return @operand1.eval(expr) < @operand2.eval(expr)
      when '<='
        return @operand1.eval(expr) <= @operand2.eval(expr)
      when '&'
        return @operand1.eval(expr) && @operand2.eval(expr)
      when '|'
        return @operand1.eval(expr) || @operand2.eval(expr)
      else
        raise "Unknown operator in logical expression"
      end
    rescue
      if @operator.nil?
        expr.error "Operand failure" # should never happen
      else
        expr.error "Can't evaluate: #{@operand1.eval(expr)} #{@operator} " +
                   "#{@operand2.eval(expr)}"
      end
    end
  end

end

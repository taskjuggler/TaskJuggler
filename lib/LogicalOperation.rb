#
# LogicalOperation.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# A LogicalOperation is the basic building block for a LogicalExpression. A
# logical operation has one or two operands and an operator. The operands can
# be LogicalOperation objects, fixed values or references to project data. The
# LogicalOperation can be evaluated in a certain context. This contexts
# determines the actual values of the project data references.
# The evaluation is done by calling LogicalOperation#eval. The result must be
# of a type that responds to all the operators that are used in the eval
# method.
class LogicalOperation

  attr_reader :operand1
  attr_accessor :operand2, :operator

  # Create a new LogicalOperation object. _opnd1_ is the mandatory operand.
  # The @operand2 and the @operator can be set later.
  def initialize(opnd1)
    @operand1 = opnd1
    @operand2 = nil
    @operator = nil
  end

  # Evaluate the expression in a given context represented by _expr_ of type
  # LogicalExpression. The result must be of a type that responds to all the
  # operators of this function.
  def eval(expr)
    begin
      case @operator
      when nil
        if @operand1.is_a?(LogicalOperation)
          return @operand1.eval(expr)
        else
          # In TJP syntax 'non 0' means false.
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
        raise TjException.new,
              "Unknown operator #{@operator} in logical expression"
      end
    rescue TjException
      expr.error "Can't evaluate #{to_s}"
    end
  end

  # Convert the operation into a textual representation. This function is used
  # for error reporting and debugging.
  def to_s
    if @operator.nil?
      @operand1.to_s
    elsif @operand2.nil?
      "#{@operator}#{@operand1}"
    else
      "#{@operand1} #{@operator} #{@operand2}"
    end
  end

end

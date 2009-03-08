#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = LogicalOperation.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjException'

class TaskJuggler

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
    def initialize(opnd1, operator = nil, opnd2 = nil)
      @operand1 = opnd1
      @operand2 = opnd2
      @operator = operator
    end

    # Evaluate the expression in a given context represented by _expr_ of type
    # LogicalExpression. The result must be of a type that responds to all the
    # operators of this function.
    def eval(expr)
      begin
        case @operator
        when nil
          if @operand1.respond_to?(:eval)
            # An operand can be a fixed value or another term. This could be a
            # LogicalOperation, LogicalFunction or anything else that provides
            # an appropriate eval() method.
            return @operand1.eval(expr)
          else
            return @operand1
          end
        when '~'
          return !coerceBoolean(@operand1.eval(expr))
        when '>'
          return coerceNumber(@operand1.eval(expr)) >
                 coerceNumber(@operand2.eval(expr))
        when '>='
          return coerceNumber(@operand1.eval(expr)) >=
                 coerceNumber(@operand2.eval(expr))
        when '='
          return coerceNumber(@operand1.eval(expr)) ==
                 coerceNumber(@operand2.eval(expr))
        when '<'
          return coerceNumber(@operand1.eval(expr)) <
                 coerceNumber(@operand2.eval(expr))
        when '<='
          return coerceNumber(@operand1.eval(expr)) <=
                 coerceNumber(@operand2.eval(expr))
        when '&'
          return coerceBoolean(@operand1.eval(expr)) &&
                 coerceBoolean(@operand2.eval(expr))
        when '|'
          return coerceBoolean(@operand1.eval(expr)) ||
                 coerceBoolean(@operand2.eval(expr))
        else
          raise TjException,
                "Unknown operator #{@operator} in logical expression"
        end
      rescue TjException
        expr.error "Can't evaluate #{to_s}"
      end
    end

    # Convert the operation into a textual representation. This function is used
    # for error reporting and debugging.
    def to_s # :nodoc:
      if @operator.nil?
        @operand1.to_s
      elsif @operand2.nil?
        "#{@operator}#{@operand1}"
      else
        "#{@operand1} #{@operator} #{@operand2}"
      end
    end

  private

    # Force the _val_ into a boolean value.
    def coerceBoolean(val)
      return val if val.class == TrueClass || val.class == FalseClass
      # In TJP logic 'non 0' means false.
      val != 0
    end

    # Force the _val_ into a number. In case this fails, an exception is raised.
    def coerceNumber(val)
      unless val.is_a?(Fixnum) || val.is_a?(Float) || val.is_a?(Bignum)
        raise TjException,
          "Operand #{val} of type #{val.class} must be a number"
      end
      val
    end

  end

end


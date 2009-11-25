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
        when '>', '>=', '=', '<', '<=', '!='
          evalOperation(expr, @operator, @operand1.eval(expr),
                        @operand2.eval(expr))
        when '&'
          return coerceBoolean(@operand1.eval(expr)) &&
                 coerceBoolean(@operand2.eval(expr))
        when '|'
          return coerceBoolean(@operand1.eval(expr)) ||
                 coerceBoolean(@operand2.eval(expr))
        else
          raise TjException.new,
                "Unknown operator #{@operator} in logical expression"
        end
      rescue TjException
        expr.error "Can't evaluate #{to_s} (#{$!.message})"
      end
    end

    # Evaluate the operation for all 2 operand operations that can be either
    # interpreted as numbers or Strings.
    def evalOperation(expr, operator, opnd1, opnd2)
      # The type of the first operand determines how the expression is
      # evaluated. If it is a number, the 2nd operator is forced to a number
      # as well. If that does not work, an error is raised. If the first
      # operator is not a number, the expression will be evaluated as a string
      # operation.
      if opnd1.is_a?(Fixnum) || opnd1.is_a?(Float) || opnd1.is_a?(Bignum)
        case operator
        when '>'
          return coerceNumber(opnd1) > coerceNumber(opnd2)
        when '>='
          return coerceNumber(opnd1) >= coerceNumber(opnd2)
        when '='
          return coerceNumber(opnd1) == coerceNumber(opnd2)
        when '<'
          return coerceNumber(opnd1) < coerceNumber(opnd2)
        when '<='
          return coerceNumber(opnd1) <= coerceNumber(opnd2)
        when '!='
          return coerceNumber(opnd1) != coerceNumber(opnd2)
        else
          raise "Operator error"
        end
      elsif opnd1.is_a?(String)
        case operator
        when '>'
          return coerceString(opnd1) > coerceString(opnd2)
        when '>='
          return coerceString(opnd1) >= coerceString(opnd2)
        when '='
          return coerceString(opnd1) == coerceString(opnd2)
        when '<'
          return coerceString(opnd1) < coerceString(opnd2)
        when '<='
          return coerceString(opnd1) <= coerceString(opnd2)
        when '!='
          return coerceString(opnd1) != coerceString(opnd2)
        else
          raise "Operator error"
        end
      else
        expr.error "First operand of a binary operation must be a number " +
                   "or a string"
      end
    end

    # Convert the operation into a textual representation. This function is used
    # for error reporting and debugging.
    def to_s
      if @operator.nil?
        @operand1.to_s
      elsif @operand2.nil?
        "#{@operator}#{@operand1.is_a?(String) ?
                       "'" + @operand1 + "'" : @operand1}"
      else
        "#{@operand1.is_a?(String) ? "'" + @operand1 + "'" :
                                     @operand1} #{@operator} #{
           @operand2.is_a?(String) ? "'" + @operand2 + "'" :
                                     @operand2}"
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
        raise TjException.new,
          "Operand #{val} of type #{val.class} must be a number"
      end
      val
    end

    # Force the _val_ into a String. In case this fails, an exception is raised.
    def coerceString(val)
      unless val.respond_to?('to_s')
        raise TjException.new,
          "Operand #{val} of type #{val.class} can't be converted into a string"
      end
      val
    end

  end

  class LogicalAttribute < LogicalOperation

    def initialize(attribute, scenario)
      @scenarioIdx = scenario
      super
    end

    def LogicalAttribute::tjpId
      'logical'
    end

    def eval(expr)
      expr.property[@operand1, @scenarioIdx]
    end

  end

  class LogicalFlag < LogicalOperation

    def initialize(opnd)
      super
    end

    def eval(expr)
      expr.property['flags', 0].include?(@operand1)
    end

    def to_s
      @operand1
    end

  end

end


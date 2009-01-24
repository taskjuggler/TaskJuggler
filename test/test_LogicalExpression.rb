#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_LogicalExpression.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'test/unit'
require 'LogicalExpression'

class TestLogicalExpression < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  def test_unaryOperations
    parameter = [
      [ true, '~', false ],
      [ false, '~', true ]
    ]

    parameter.each do |op, operator, result|
      exp = LogicalExpression.new(unaryOp(op, operator))
      assert_equal(result, exp.eval(nil, nil),
                  "Operation #{operator} #{op} -> #{result} failed")
    end
  end

  def test_binaryOperations
    parameter = [
      [ 2, '<', 3, true ],
      [ 3, '<', 2, false ],
      [ 2, '<', 2, false ],
      [ 4, '>', 5, false ],
      [ 5, '>', 4, true ],
      [ 5, '>', 5, false ],
      [ 2, '<=', 3, true ],
      [ 3, '<=', 2, false ],
      [ 2, '<=', 2, true],
      [ 4, '>=', 5, false ],
      [ 5, '>=', 4, true ],
      [ 5, '>=', 5, true],
      [ 6, '=', 5, false ],
      [ 6, '=', 6, true],
      [ true, '&', true, true ],
      [ true, '&', false, false ],
      [ false, '&', true, false ],
      [ false, '&', false, false ],
      [ 1, '&', 1, true ],
      [ 1, '&', 0, false ],
      [ 0, '&', 1, false ],
      [ 0, '&', 0, false ],
      [ true, '|', true, true ],
      [ true, '|', false, true ],
      [ false, '|', true, true ],
      [ false, '|', false, false ]
    ]

    parameter.each do |op1, operator, op2, result|
      exp = LogicalExpression.new(binaryOp(op1, operator, op2))
      assert_equal(result, exp.eval(nil, nil),
                  "Operation #{op1} #{operator} #{op2} -> #{result} failed")
    end
  end

  def test_operationTrees
    op1 = binaryOp(2, '<', 4)
    op2 = binaryOp(3, '>', 6)
    exp = LogicalExpression.new(binaryOp(op1, '|', op2))
    assert_equal(true, exp.eval(nil, nil),
                 "Operation #{exp} -> true failed")
  end

  def test_exceptions
    begin
      exp = LogicalExpression.new(binaryOp(false, '<', true))
      assert_raise TjException do
        exp.eval(nil, nil)
      end
    rescue TjException
    end
  end

private

  def binaryOp(op1, operator, op2)
    LogicalOperation.new(LogicalOperation.new(op1), operator,
                         LogicalOperation.new(op2))
  end

  def unaryOp(op, operator)
    exp = LogicalOperation.new(LogicalOperation.new(op), operator)
  end

end



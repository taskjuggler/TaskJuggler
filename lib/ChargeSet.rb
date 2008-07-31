#
# ChargeSet.rb - The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TjException'

# A charge set describes how a given amount is distributed over a set of
# accounts. It stores the percentage share for each account. The accumulated
# percentages must always be 100% for a valid charge set. For consistency
# reasons, accounts must always be leaf accounts of the same top-level
# account. Percentage values must range from 0.0 to 1.0.
class ChargeSet

  attr_reader :master

  # Create a new ChargeSet object.
  def initialize
    @set = {}
    @master = nil
  end

  # Add a new account to the set. Accounts and share rates must meet a number
  # of requirements. This method does some error checking and raises a
  # TjException in case of problems. It cannot check everything. Accounts can
  # later be turned into group accounts or the total share sum may not be
  # 100%. This needs to be checked at a later stage. Accounts may have a share
  # of nil. This will be set in ChargeSet#complete later.
  def addAccount(account, share)
    unless account.leaf?
      raise TjException.new,
        "Account #{account.fullId} is a group account and cannot be used " +
        "in a chargeset."
    end
    if @set.include?(account)
      raise TjException.new,
        "Account #{account.fullId} is already a member of the charge set."
    end
    if @master.nil?
      @master = account.root
    elsif @master != account.root
      raise TjException.new,
        "All members of this charge set must belong to the " +
        "#{@master.fullId} account. #{account.fullId} belongs to " +
        "#{account.root.fullId}."
    end
    if account.container?
      raise TjException.new,
        "#{account.fullId} is a group account. Only leaf accounts are " +
        "allowed for a charge set."
    end
    if share && (share < 0.0 || share > 1.0)
      raise TjException.new, "Charge set shares must be between 0 and 100%"
    end
    @set[account] = share
  end

  def each
    @set.each do |account, share|
      yield account, share
    end
  end

  # Check for accounts that don't have a share yet and distribute the
  # remainder to 100% evenly accross them.
  def complete
    # Calculate the current total share.
    totalPercent = 0.0
    undefined = 0
    @set.each_value do |share|
      if share
        totalPercent += share
      else
        undefined += 1
      end
    end
    # Must be less than 100%.
    if totalPercent > 1.0
      raise TjException.new,
        "Total share of this set (#{totalPercent * 100}%) excedes 100%."
    end
    if undefined > 0
      commonShare = (1.0 - totalPercent) / undefined
      if commonShare <= 0
        raise TjException.new,
          "Total share is 100% but #{undefined} account(s) still exist."
      end
      @set.each do |account, share|
        if share.nil?
          @set[account] = commonShare
        end
      end
    elsif totalPercent != 1.0
      raise TjException.new,
        "Total share of this set is #{totalPercent * 100} instead of 100%."
    end
  end

  # Return the share percentage for a given Account _account_.
  def share(account)
    @set[account]
  end

  # Return the set as comma separated list of account ID + share pairs.
  def to_s
    str = '('
    @set.each do |account, share|
      str += ', ' unless str == '('
      str += "#{account.fullId} #{share * 100}%"
    end
    str += ')'
  end

end

#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = SheetSender.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010, 2011
#               by Chris Schlaeger <chris@linux.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'open4'
require 'mail'
require 'yaml'
require 'SheetHandlerBase'
require 'reports/CSVFile'

class TaskJuggler

  # A base class for sheet senders.
  class SheetSender < SheetHandlerBase

    attr_accessor :force, :intervalDuration

    def initialize(appName, type)
      super(appName)

      @sheetType = type
      # The following settings must be provided by the deriving class.
      # This is a LogicalExpression string that controls what resources should
      # not be getting a report sheet template.
      @hideResource = nil
      # This file contains the signature (date or interval) that the
      # SheetReceiver will accept as a valid signature.
      @signatureFile = nil
      # The base directory of the sheet templates.
      @templateDir = nil
      # When true, existing templates will be regenerated and send out again.
      # Otherwise the existing template will not be send out again.
      @force = false

      @signatureFilter = nil
      # The subject of the template email.
      @mailSubject = nil
      # The into text of the template email.
      @introText = nil

      # The end date of the reported interval.
      @date = Time.new.strftime('%Y-%m-%d')
      # Determines the length of the reported interval.
      @intervalDuration = '1w'
      # We need this to determine if we already sent out a report.
      @timeStamp = Time.new
    end

    # Send out report templates to a list of project resources. The resources
    # are selected by the @hideResource filter expression and can be further
    # limited with a list of resource IDs passed by _resourceList_.
    def sendTemplates(resourceList)
      setWorkingDir
      createDirectories

      resources = genResourceList(resourceList)
      genTemplates(resources)
      sendReportTemplates(resources)
    end

    private

    def createDirectories
      unless File.directory?(@templateDir)
        warning("Creating directory #{@templateDir}")
        Dir.mkdir(@templateDir)
      end
      @templateDir += "/#{@date}"
      unless File.directory?(@templateDir)
        Dir.mkdir(@templateDir)
      end
    end

    def genResourceList(resourceList)
      list = []
      info('Retrieving resource list...')
      # Create a TJP report definition for a CSV report that contains the id,
      # name, email, effort and free work for each resource that is not hidden
      # by @hideResource.
      reportDef = <<"EOF"
resourcereport rl_21497214 '.' {
  formats csv
  columns id, name, email, effort, freework, efficiency
  hideresource #{@hideResource}
  sortresources id.up
  loadunit days
  period %{#{@date} - 1w} +1w
}
EOF
      report = generateReport('rl_21497214', reportDef)
      # Parse the CSV report into an Array of Arrays
      csv = CSVFile.new.parse(report)

      # Get rid of the column title line
      csv.delete_at(0)

      # Process the CSV report line by line
      csv.each do |id, name, email, effort, free, efficiency|
        if email.nil? || email.empty?
          error("Resource '#{id}' must have a valid email address")
        end

        # Ignore resources that are on vacation for the whole period.
        if effort == 0.0 && free == 0.0 && efficiency != 0.0
          info("Resource '#{id}' was on vacation the whole period")
          next
        end

        list << [ id, name, email, effort, free ]
      end

      # Save the resource list to a file. We'll need it in the receiver again.
      begin
        fileName = @templateDir + '/resources.yml'
        File.open(fileName, 'w') do |file|
          YAML.dump(list, file)
        end
      rescue
        error("Saving of #{fileName} failed: #{$!}")
      end

      unless resourceList.empty?
        # When the user specified resource list is empty, we generate templates
        # for all users that don't match the @hideResource filter. Otherwise we
        # only generate templates for those in the list and that are not hidden
        # by the filter.
        list.delete_if { |item| !resourceList.include?(item[0]) }
      end

      error('genResourceList: list is empty') if list.empty?

      info("#{list.length} resources found")
      list
    end

    def genTemplates(resources)
      firstTemplateFile = nil
      resources.each do |resInfo|
        res = resInfo[0]
        info("Generating template for #{res}...")
        reportId = "sheet_template_#{res}"
        templateFile = "#{@templateDir}/#{res}_#{@date}"
        # We use the first template file to get the sheet interval.
        firstTemplateFile = templateFile + '.tji' unless firstTemplateFile

        # Don't re-generate already existing templates unless we are in force
        # mode. We probably have sent them out earlier with a manual trigger.
        if !@force && File.exist?(templateFile + '.tji')
          info("Skipping already existing #{templateFile}.tji.")
          next
        end

        reportDef = <<"EOT"
#{@sheetType}sheetreport #{reportId} \"#{templateFile}\" {
  hideresource ~(plan.id = \"#{res}\")
  period %{#{@date} - #{@intervalDuration}} +#{@intervalDuration}
  sorttasks id.up
}
EOT
        generateReport(reportId, reportDef)
      end
      enableSignatureForReporting(firstTemplateFile)
    end

    def sendReportTemplates(resources)
      resources.each do |id, name, email|
        attachment = "#{@templateDir}/#{id}_#{@date}.tji"
        unless File.exist?(attachment)
          error("sendReportTemplates: " +
                "#{@sheetType} sheet #{attachment} for #{name} not found")
        end
        # Don't send out old templates again. @timeStamp has a higher
        # resolution. We add 1s to avoid truncation errors.
        if (File.mtime(attachment) + 1) < @timeStamp
          info("Old template #{attachment} found. Not sending it out.")
          next
        end

        message = " Hello #{name}!\n\n#{@introText}" + File.read(attachment)

        sendEmail(email, sprintf(@mailSubject, @date), message, attachment)
      end
    end

    def enableSignatureForReporting(templateFile)
      signature = nil
      # That's a pretty bad hack to make reasonably certain that the tj3 server
      # process has put the complete file into the file system.
      i = 0
      begin
        if File.exist?(templateFile)
          File.open(templateFile, 'r') do |file|
            while (line = file.gets)
              if matches = @signatureFilter.match(line)
                signature = matches[1]
              end
            end
          end
        end
        i += 1
        # If the file doesn't exist yet or the cannot yet be read, wait for
        # 300ms. We try this 100 times.
        sleep(0.3) unless signature
      end while signature.nil? && i < 100
      unless signature
        error("enableSignatureForReporting: Cannot find signature in file " +
              "#{templateFile}")
      end

      acceptedSignatures = []
      if File.exist?(@signatureFile)
        File.open(@signatureFile, 'r') do |file|
          acceptedSignatures = file.readlines
        end
        acceptedSignatures.map! { |s| s.chomp }
        acceptedSignatures.delete_if { |s| s.chomp.empty? }
      else
        info("#{@signatureFile} does not exist yet.")
      end
      unless acceptedSignatures.include?(signature)
        # Add the new signature
        info("Adding #{signature} to #{@signatureFile}")
        acceptedSignatures << signature
        # And write back the adapted file.
        File.open(@signatureFile, 'w') do |file|
          acceptedSignatures.each do |iv|
            file.write("#{iv}\n")
          end
        end
      else
        info("Signature #{signature} is already listed in #{@signatureFile}")
      end
    end

    def generateReport(id, reportDef)
      out = ''
      err = ''
      begin
        command = "tj3client --silent report #{@projectId} #{id} = ."
        status = Open4.popen4(command) do |pid, stdin, stdout, stderr|
          # Send the report definition to the tj3client process via stdin.
          stdin.write(reportDef)
          stdin.close
          # Retrieve the output
          out = stdout.read
          err = stderr.read
        end
        if status.exitstatus != 0
          error("generateReport: #{err}")
        end
      rescue
        error("generateReport: Report generation failed: #{$!}")
      end
      out
    end

  end

end


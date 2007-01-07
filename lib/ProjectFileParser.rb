require 'Project'
require 'TextParser'

class ProjectFileParser < TextParser

  def initialize
    super
    newRule('project')
    newPattern(%w( !projectHeader !projectBody !properties ), Proc.new {
      @val[0]
    })

    newRule('projectHeader')
    newPattern(%w( _project $ID $STRING $STRING !interval ), Proc.new {
      @project = Project.new(@val[1], @val[2], @val[3])
      @project['start'] = @val[4].start
      @project['end'] = @val[4].end
      @task = nil
      @resource = nil
      @project
    })

    newRule('interval')
    newPattern(%w( $DATE !intervalEnd ), Proc.new {
      mode = @val[1][0]
      endSpec = @val[1][1]
      if mode == 0
        Interval.new(@val[0], endSpec)
      else
        Interval.new(@val[0], @val[0] + endSpec)
      end
    })

    newRule('intervalEnd')
    newPattern([ '_ - ', '$DATE' ], Proc.new {
      [ 0, @val[1] ]
    })
    newPattern(%w( _+ !duration ), Proc.new {
      [ 1, @val[1] ]
    })

    newRule('duration')
    newPattern(%w( $INTEGER $ID ))

    newRule('projectBody')
    optional
    newPattern(%w( _{  !projectBodyAttributes _} ))

    newRule('projectBodyAttributes')
    repeatable
    optional
    newPattern(%w( !timezone ))

    newRule('timezone')
    newPattern(%w( _timezone $STRING ))

    newRule('properties')
    repeatable
    newPattern(%w( !resource ))
    newPattern(%w( !task ))
    newPattern(%w( !report ))

    newRule('resource')
    newPattern(%w( !resourceHeader !resourceBody ), Proc.new {
       @resource = @resource.parent
    })

    newRule('resourceHeader')
    newPattern(%w( _resource $ID $STRING ), Proc.new {
      @resource = Resource.new(@project, @val[1], @val[2], @resource)
    })

    newRule('resourceBody')
    optional
    newPattern(%w( _{ !resourceAttributes _} ))

    newRule('resourceAttributes')
    repeatable
    optional
    newPattern(%w( !resource ))

    newRule('task')
    newPattern(%w( !taskHeader !taskBody ), Proc.new {
      @task = @task.parent
    })

    newRule('taskHeader')
    newPattern(%w( _task $ID $STRING ), Proc.new {
      @task = Task.new(@project, @val[1], @val[2], @task)
      @scenarioIdx = 0
    })

    newRule('taskBody')
    optional
    newPattern(%w( _{ !taskAttributes _} ))

    newRule('taskAttributes')
    repeatable
    optional
    newPattern(%w( !task ))
    newPattern(%w( !taskScenarioAttributes ))
    newPattern(%w( $ID_WITH_COLON !taskScenarioAttributes ), Proc.new {
      if (@scenarioIdx = @project.scenarioIdx(@val[0])).nil?
        error("Unknown scenario: @val[0]")
      end
    })

    newRule('taskScenarioAttributes')
    newPattern(%w( _start $DATE ), Proc.new {
      @task['start', @scenarioIdx] = @val[1]
      @scenarioIdx = 0
    })
    newPattern(%w( _end $DATE ))

    newRule('report')
    newPattern(%w( !reportHeader !reportBody ))

    newRule('reportHeader')
    newPattern(%w( !reportType $STRING ), Proc.new {
      case @val[0]
      when 'htmltaskreport'
        @report = HTMLTaskReport.new(@project, @val[1])
        @reportElement = ReportElement.new(@report)
        @reportElement.columns = %w( name start end )
      end
    })

    newRule('reportType')
    newPattern(%w( _htmltaskreport ), Proc.new {
      @val[0]
    })

    newRule('reportBody')
    optional
    newPattern(%w( _{ !reportAttributes _} ))

    newRule('reportAttributes')
    optional
    repeatable
    newPattern(%w( _foo ))
  end

  def open(masterFile)
    @scanner = TextScanner.new(masterFile)
    @scanner.open

    @task = nil
    @parentTask = nil
  end

  def close
    @scanner.close
  end

  def nextToken
    @scanner.nextToken
  end

  def returnToken(token)
    @scanner.returnToken(token)
  end

  def addAttribute(property, attributeName, attributeType)
    @cr = @rules[property + "Body"]
    addPattern([ "_" + attributeName, "!" + attributeType ])
  end

end

parser = ProjectFileParser.new
parser.updateTransitions
parser.open('test.prj')
project = parser.parse('project')
parser.close
project.schedule
project.generateReports
puts project.task('foo1')['end', 0]

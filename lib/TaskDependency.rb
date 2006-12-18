class TaskDependency

  attr_reader :gapDuration, :gapLength, :taskId, :task

  def initialize(taskId)
    @taskId = taskId
    @gapDuration = 0
    @gapLength = 0
  end

  def resolve(project)
    @task = project.task(@taskId)
  end

end


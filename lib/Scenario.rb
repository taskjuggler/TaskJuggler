
require 'PropertyTreeNode'

class Scenario < PropertyTreeNode

  def initialize(project, id, name, parent)
    super(project.scenarios, id, name, parent)
    project.addScenario(self)
  end

end


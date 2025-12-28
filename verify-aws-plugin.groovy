import jenkins.model.*

def plugin = Jenkins.get().pluginManager.getPlugin("aws-credentials")
if (plugin == null) {
  throw new RuntimeException("aws-credentials plugin NOT loaded")
}
println("aws-credentials plugin is loaded")

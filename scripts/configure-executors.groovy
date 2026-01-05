import jenkins.model.*

def jenkins = Jenkins.instance

// Set number of executors to 5 (allows multiple template jobs to run in parallel)
jenkins.setNumExecutors(5)
jenkins.save()

println("✅ Set Jenkins executors to: ${jenkins.getNumExecutors()}")

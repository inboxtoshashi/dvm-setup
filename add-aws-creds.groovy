import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.jenkins.plugins.awscredentials.*

def store = Jenkins.get()
  .getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0]
  .getStore()

if (!CredentialsProvider.lookupCredentials(
  AWSCredentialsImpl.class, Jenkins.get(), null, null
).find { it.id == 'aws-creds' }) {
  store.addCredentials(Domain.global(),
    new AWSCredentialsImpl(
      CredentialsScope.GLOBAL,
      "aws-creds",
      "Placeholder AWS credentials",
      "DUMMY",
      "DUMMY"
    )
  )
}

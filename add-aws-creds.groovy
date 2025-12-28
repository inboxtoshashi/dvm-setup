import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.jenkins.plugins.awscredentials.*
import jenkins.model.*

def store = Jenkins.get()
  .getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0]
  .getStore()

def existing = CredentialsProvider.lookupCredentials(
  AWSCredentials.class,
  Jenkins.get(),
  null,
  null
).find { it.id == 'aws-creds' }

if (existing == null) {
  store.addCredentials(
    Domain.global(),
    new AWSCredentialsImpl(
      CredentialsScope.GLOBAL,
      'aws-creds',
      'Placeholder AWS credentials',
      'DUMMY',
      'DUMMY'
    )
  )
}

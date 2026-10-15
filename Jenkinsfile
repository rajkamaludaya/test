// Step 1: plain C build directly on the Linux PC (no Docker).
// Later: switch the agent line to  agent { dockerfile { dir 'ci' } }  — the stages stay the same.
pipeline {
  agent any
  options {
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))   // keep last 10 builds + reports
    timestamps()
  }
  stages {
    stage('Build')           { steps { sh './ci/build.sh build' } }
    stage('Static analysis') { steps { sh './ci/build.sh analyze' } }
    stage('Test')            { steps { sh './ci/build.sh test' } }
  }
  post {
    always {
      sh './ci/build.sh report'
      archiveArtifacts artifacts: 'out/**', allowEmptyArchive: true
      publishHTML(target: [               // needs the "HTML Publisher" plugin
        reportName: 'Visible Report', reportDir: 'out/report', reportFiles: 'index.html',
        keepAll: true, alwaysLinkToLastBuild: true, allowMissing: true
      ])
    }
  }
}

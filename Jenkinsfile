ipeline {
  agent any

  environment {
    GITSERVICE = 'github-jenkins'
    GITHUB_CRED = credentials('github-Understand-texhmatrix')
    GITHUB_URL  = "https://github.com/ito-takeshi-01/understand_test-tmrx"
    
    STORAGESERVICE = 'aws-s3'
    AWS_S3_BUCKET_NAME = 'ltxund-jenkins-storage'
    AWS_REGION = 'ap-northeast-1'
    AWS = credentials('AWS_CRED')
    // STORAGESERVICE = 'nexus'
    // NEXUS_URL = "http://172.20.128.8"
    // NEXUS_CREDENTIALS_FILE = credentials('NEXUS_CREDENTIALS_FILE')
  }
  
  options {
    buildDiscarder logRotator(numToKeepStr: '10')
  }
  
  stages {
    stage('解析') {
      when {
          anyOf {
              branch 'main'
              changeRequest target: 'main'
          }
      }
      steps {
        bat '''
          set
          cd understand
          bash analyze.sh --upload
        '''
      }
    }
    
    stage('PRレビュー') {
      when {
        changeRequest target: 'main'
      }
      steps {
        bat '''
          cd understand
          bash generate-graphs.sh > review-comment.txt
          bash review-pr.sh review-comment.txt
        '''
      }
    }
  }
  
  post {
    always {
      script {
        try {
          bat 'cd understand && bash clean.sh'
        } catch (Exception e) {
          echo "Cleanup failed: ${e.message}"
        }
      }
    }
  }
}
pipeline {
  agent {
    // TBE:Jenkins エージェントのラベルを指定する
    label 'Understand'
  }
  environment {
    GITSERVICE = 'github-jenkins'
    GITHUB_CRED = credentials('GitHub Tomoyoshi')
    // Github の URL を指定する
    GITHUB_URL  = "https://github.com/tmx-tomoyoshi/fastgrep"
    
    // TBE:使用するストレージのアクセス情報を指定する
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
        sh '''
          env
          chmod 755 ./understand/analyze.sh
          ./understand/analyze.sh --upload
        '''
      }
    }
    stage('PRレビュー') {
      when {
        changeRequest target: 'main'
      }
      steps {
        sh '''
          chmod 755 ./understand/generate-graphs.sh
          chmod 755 ./understand/review-pr.sh
          ./understand/generate-graphs.sh > review-comment.txt
          ./understand/review-pr.sh review-comment.txt
        '''
      }
    }
  }
  post {
    cleanup {
      sh 'chmod 755 ./understand/clean.sh'
      sh './understand/clean.sh'
    }
  }
}
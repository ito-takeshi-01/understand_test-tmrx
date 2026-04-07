pipeline {
  agent none

  options {
    buildDiscarder(logRotator(numToKeepStr: '3'))
    skipDefaultCheckout(true)
  }

  parameters {
    choice(name: 'BUILD_TYPE', choices: ['NONE', 'MASTER', 'FEATURE'],
      description: '手動で実行するビルドの種類。NONEはMultibranchのみ。')
    string(name: 'LOCAL_STORAGE_PATH', defaultValue: 'C:\\work\\understand_data\\test_prj',
      description: '解析DB/画像の保存先（Windowsパス）')
    string(name: 'FEATURE_BRANCH_NAME', defaultValue: 'develop',
      description: 'BUILD_TYPE=FEATUREの場合の対象ブランチ名')
  }

  environment {
    UND_BIN_DIR = 'C:\\Program Files\\SciTools\\bin\\pc-win64'
    GIT_BASH_PATH = 'C:\\Program Files\\Git\\bin\\bash.exe'
    GITHUB_URL = 'https://github.com/ito-takeshi-01/understand_test.git'
    GITSERVICE = 'github2'
    STORAGESERVICE = 'local'
    http_proxy  = 'http://proxy.mei.co.jp:8080/'
    https_proxy = 'http://proxy.mei.co.jp:8080/'
    PROXY_HOST = 'proxy.mei.co.jp'
    PROXY_PORT = '8080'
  }

  stages {
    stage('Checkout (understand-agent)') {
      agent { label 'understand-agent' }
      steps {
        checkout scm
      }
    }

    stage('Configure Understand Proxy') {
      agent { label 'understand-agent' }
      steps {
        bat """
          @echo off
          setlocal
          set GLOBAL_INI=%APPDATA%\\SciTools\\conf\\Understand\\global.ini
          if not exist "%APPDATA%\\SciTools\\conf\\Understand" mkdir "%APPDATA%\\SciTools\\conf\\Understand"

          echo [Proxy] > "%GLOBAL_INI%"
          echo Host=${PROXY_HOST} >> "%GLOBAL_INI%"
          echo Port=${PROXY_PORT} >> "%GLOBAL_INI%"
          echo Credentials= >> "%GLOBAL_INI%"
          type "%GLOBAL_INI%"
        """
      }
    }

    stage('Debug: Who am I (understand-agent)') {
      agent { label 'understand-agent' }
      steps {
        bat """
          @echo off
          setlocal
          whoami
          echo USERNAME=%USERNAME%
          echo USERPROFILE=%USERPROFILE%
          set PATH=${UND_BIN_DIR};%PATH%
          where und
          und license
        """
      }
    }

    stage('Manual Build Setup') {
      agent { label 'understand-agent' }
      when { expression { params.BUILD_TYPE != 'NONE' } }
      steps {
        script {
          if (params.BUILD_TYPE == 'MASTER') {
            env.TARGET_BRANCH = 'master'
          } else if (params.BUILD_TYPE == 'FEATURE') {
            env.TARGET_BRANCH = params.FEATURE_BRANCH_NAME
          }
          echo "Manual build triggered for branch: ${env.TARGET_BRANCH}"
        }
      }
    }

    stage('Baseline Analysis (master)') {
      agent { label 'understand-agent' }
      when {
        anyOf {
          expression { params.BUILD_TYPE == 'MASTER' }
          expression { params.BUILD_TYPE == 'NONE' && env.BRANCH_NAME == 'master' }
        }
      }
      steps {
        script {
          if (params.BUILD_TYPE == 'MASTER') {
            checkout([$class: 'GitSCM',
              branches: [[name: '*/master']],
              userRemoteConfigs: [[url: env.GITHUB_URL, credentialsId: 'GitHub-Understand5']]
            ])
          }
        }

        bat """
          @echo off
          setlocal
          set PATH=${UND_BIN_DIR};%PATH%

          set "WINP=${params.LOCAL_STORAGE_PATH}"
          set "BASH_P=%WINP:\\=/%"
          set "BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%"
          set "LOCAL_STORAGE_PATH=%BASH_P%"

          "${GIT_BASH_PATH}" -lc "./understand/analyze.sh --upload"
        """
      }
    }

    stage('Comparison Analysis (feature)') {
      agent { label 'understand-agent' }
      when {
        anyOf {
          expression { params.BUILD_TYPE == 'FEATURE' }
          expression { params.BUILD_TYPE == 'NONE' && env.BRANCH_NAME != null && env.BRANCH_NAME != 'master' }
        }
      }
      steps {
        script {
          if (params.BUILD_TYPE == 'FEATURE') {
            checkout([$class: 'GitSCM',
              branches: [[name: "*/${params.FEATURE_BRANCH_NAME}"]],
              userRemoteConfigs: [[url: env.GITHUB_URL, credentialsId: 'GitHub-Understand5']]
            ])
            env.TARGET_BRANCH = params.FEATURE_BRANCH_NAME
          } else {
            env.TARGET_BRANCH = env.BRANCH_NAME
          }
        }

        withCredentials([string(credentialsId: 'GITHUB_CRED', variable: 'GITHUB_TOKEN_FROM_JENKINS')]) {
          bat """
            @echo off
            setlocal
            set PATH=${UND_BIN_DIR};%PATH%
            set GITHUB_TOKEN=%GITHUB_TOKEN_FROM_JENKINS%
            set BRANCH_NAME=${env.TARGET_BRANCH}

            set "WINP=${params.LOCAL_STORAGE_PATH}"
            set "BASH_P=%WINP:\\=/%"
            set "BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%"
            set "LOCAL_STORAGE_PATH=%BASH_P%"

            "${GIT_BASH_PATH}" -lc "./understand/analyze.sh"
            "${GIT_BASH_PATH}" -lc "./understand/generate-graphs.sh > review-comment.txt"
            "${GIT_BASH_PATH}" -lc "./understand/review-pr.sh review-comment.txt"
          """
        }
      }
    }
  }

  post {
    always {
      node('understand-agent') {
        bat """
          @echo off
          setlocal
          set PATH=${UND_BIN_DIR};%PATH%

          set "WINP=${params.LOCAL_STORAGE_PATH}"
          set "BASH_P=%WINP:\\=/%"
          set "BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%"
          set "LOCAL_STORAGE_PATH=%BASH_P%"

          "${GIT_BASH_PATH}" -lc "./understand/clean.sh"
        """
      }
    }
  }
}
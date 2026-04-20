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
    UND_BIN_DIR     = 'C:\\Program Files\\SciTools\\bin\\pc-win64'
    GIT_BASH_PATH   = 'C:\\Program Files\\Git\\bin\\bash.exe'
    GITHUB_URL      = 'https://github.com/ito-takeshi-01/understand_test.git'
    GITSERVICE      = 'github2'
    STORAGESERVICE  = 'local'
    http_proxy      = 'http://proxy.mei.co.jp:8080/'
    https_proxy     = 'http://proxy.mei.co.jp:8080/'
    PROXY_HOST      = 'proxy.mei.co.jp'
    PROXY_PORT      = '8080'
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
          
          // Git情報を取得
          def gitCommit = bat(script: '@git rev-parse HEAD', returnStdout: true).trim().readLines().last()
          def gitUrl = env.GITHUB_URL
          def branchName = env.TARGET_BRANCH ?: env.BRANCH_NAME ?: 'master'
          
          echo "DEBUG: GIT_COMMIT = ${gitCommit}"
          echo "DEBUG: GIT_URL = ${gitUrl}"
          echo "DEBUG: BRANCH_NAME = ${branchName}"
          
          // 環境変数として設定
          env.GIT_COMMIT_HASH = gitCommit
          env.GIT_URL_VALUE = gitUrl
          env.CURRENT_BRANCH = branchName
        }

        bat """
          @echo off
          setlocal EnableDelayedExpansion
          set PATH=${UND_BIN_DIR};%PATH%

          REM ローカルストレージパスをBash形式に変換
          set "WINP=${params.LOCAL_STORAGE_PATH}"
          set "BASH_P=!WINP:\\=/!"
          set "BASH_P=/!BASH_P:~0,1!/!BASH_P:~3!"
          
          REM 環境変数を設定
          set "LOCAL_STORAGE_PATH=!BASH_P!"
          set "GIT_URL=${env.GIT_URL_VALUE}"
          set "GIT_COMMIT=${env.GIT_COMMIT_HASH}"
          set "BRANCH_NAME=${env.CURRENT_BRANCH}"
          set "CHANGE_ID="
          
          echo --- Environment Variables ---
          echo LOCAL_STORAGE_PATH=!LOCAL_STORAGE_PATH!
          echo GIT_URL=!GIT_URL!
          echo GIT_COMMIT=!GIT_COMMIT!
          echo BRANCH_NAME=!BRANCH_NAME!
          echo ---
          
          "${GIT_BASH_PATH}" -lc "export GIT_URL='!GIT_URL!' && export GIT_COMMIT='!GIT_COMMIT!' && export BRANCH_NAME='!BRANCH_NAME!' && export LOCAL_STORAGE_PATH='!LOCAL_STORAGE_PATH!' && export CHANGE_ID='' && ./understand/analyze.sh --upload"
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
          
          // Git情報を取得
          def gitCommit = bat(script: '@git rev-parse HEAD', returnStdout: true).trim().readLines().last()
          def gitUrl = env.GITHUB_URL
          def branchName = env.TARGET_BRANCH
          
          echo "DEBUG: GIT_COMMIT = ${gitCommit}"
          echo "DEBUG: GIT_URL = ${gitUrl}"
          echo "DEBUG: BRANCH_NAME = ${branchName}"
          
          // 環境変数として設定
          env.GIT_COMMIT_HASH = gitCommit
          env.GIT_URL_VALUE = gitUrl
          env.CURRENT_BRANCH = branchName
        }

        withCredentials([string(credentialsId: 'GITHUB_CRED', variable: 'GITHUB_TOKEN_FROM_JENKINS')]) {
          bat """
            @echo off
            setlocal EnableDelayedExpansion
            set PATH=${UND_BIN_DIR};%PATH%
            set GITHUB_TOKEN=%GITHUB_TOKEN_FROM_JENKINS%

            REM ローカルストレージパスをBash形式に変換
            set "WINP=${params.LOCAL_STORAGE_PATH}"
            set "BASH_P=!WINP:\\=/!"
            set "BASH_P=/!BASH_P:~0,1!/!BASH_P:~3!"
            
            REM 環境変数を設定
            set "LOCAL_STORAGE_PATH=!BASH_P!"
            set "GIT_URL=${env.GIT_URL_VALUE}"
            set "GIT_COMMIT=${env.GIT_COMMIT_HASH}"
            set "BRANCH_NAME=${env.CURRENT_BRANCH}"
            set "CHANGE_ID="
            
            echo --- Environment Variables ---
            echo LOCAL_STORAGE_PATH=!LOCAL_STORAGE_PATH!
            echo GIT_URL=!GIT_URL!
            echo GIT_COMMIT=!GIT_COMMIT!
            echo BRANCH_NAME=!BRANCH_NAME!
            echo GITHUB_TOKEN is set: YES
            echo ---
            
            echo --- 1. Analyzing current branch ---
            "${GIT_BASH_PATH}" -lc "export GIT_URL='!GIT_URL!' && export GIT_COMMIT='!GIT_COMMIT!' && export BRANCH_NAME='!BRANCH_NAME!' && export LOCAL_STORAGE_PATH='!LOCAL_STORAGE_PATH!' && export GITHUB_TOKEN='!GITHUB_TOKEN!' && export CHANGE_ID='' && ./understand/analyze.sh"
            
            echo --- 2. Generating graphical report for PR ---
            "${GIT_BASH_PATH}" -lc "export GIT_URL='!GIT_URL!' && export GIT_COMMIT='!GIT_COMMIT!' && export BRANCH_NAME='!BRANCH_NAME!' && export LOCAL_STORAGE_PATH='!LOCAL_STORAGE_PATH!' && export GITHUB_TOKEN='!GITHUB_TOKEN!' && export CHANGE_ID='' && ./understand/generate-graphs.sh > review-comment.txt"
            
            echo --- 3. Posting review comment to PR ---
            "${GIT_BASH_PATH}" -lc "export GIT_URL='!GIT_URL!' && export GIT_COMMIT='!GIT_COMMIT!' && export BRANCH_NAME='!BRANCH_NAME!' && export LOCAL_STORAGE_PATH='!LOCAL_STORAGE_PATH!' && export GITHUB_TOKEN='!GITHUB_TOKEN!' && export CHANGE_ID='' && ./understand/review-pr.sh review-comment.txt"
          """
        }
      }
    }
  }

  post {
    always {
      node('understand-agent') {
        script {
          // Git情報を取得（クリーンアップ用）
          def gitCommit = ''
          def branchName = ''
          try {
            gitCommit = bat(script: '@git rev-parse HEAD 2>nul', returnStdout: true).trim().readLines().last()
          } catch (Exception e) {
            gitCommit = 'unknown'
          }
          branchName = env.CURRENT_BRANCH ?: env.TARGET_BRANCH ?: env.BRANCH_NAME ?: 'master'
          
          env.GIT_COMMIT_HASH = gitCommit
          env.CURRENT_BRANCH = branchName
        }
        
        bat """
          @echo off
          setlocal EnableDelayedExpansion
          set PATH=${UND_BIN_DIR};%PATH%

          REM ローカルストレージパスをBash形式に変換
          set "WINP=${params.LOCAL_STORAGE_PATH}"
          set "BASH_P=!WINP:\\=/!"
          set "BASH_P=/!BASH_P:~0,1!/!BASH_P:~3!"
          
          REM 環境変数を設定
          set "LOCAL_STORAGE_PATH=!BASH_P!"
          set "GIT_COMMIT=${env.GIT_COMMIT_HASH}"
          set "BRANCH_NAME=${env.CURRENT_BRANCH}"
          
          echo --- Cleanup Environment Variables ---
          echo LOCAL_STORAGE_PATH=!LOCAL_STORAGE_PATH!
          echo GIT_COMMIT=!GIT_COMMIT!
          echo BRANCH_NAME=!BRANCH_NAME!
          echo ---
          
          "${GIT_BASH_PATH}" -lc "export GIT_COMMIT='!GIT_COMMIT!' && export BRANCH_NAME='!BRANCH_NAME!' && export LOCAL_STORAGE_PATH='!LOCAL_STORAGE_PATH!' && ./understand/clean.sh"
        """
      }
    }
  }
}
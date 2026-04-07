 pipeline {
  agent none

  // Multibranch Pipeline では Webhook/定期スキャン（ジョブ設定側）で検知させるのが基本です。
  // Jenkinsfile側の pollSCM は混乱の元になりやすいので削除推奨。
  // triggers { pollSCM('H/15 * * * *') }

  parameters {
    choice(
      name: 'BUILD_TYPE',
      choices: ['NONE', 'MASTER', 'FEATURE'],
      description: '手動で実行するビルドの種類を選択します。NONEの場合はMultibranchのスキャンでのみ動作します。'
    )
    string(
      name: 'LOCAL_STORAGE_PATH',
      defaultValue: 'C:\\work\\understand_data\\test_prj',
      description: '解析DB/画像の保存先（Windowsパス）'
    ) 
    string(
      name: 'FEATURE_BRANCH_NAME',
      defaultValue: 'develop',
      description: 'BUILD_TYPEでFEATUREを選択した場合に、対象となるブランチ名を入力します。'
    )
  }

  environment {
    // Understand
    PATH = "C:\\Program Files\\SciTools\\bin\\pc-win64;${env.PATH}"

    // scripts selection
    GITSERVICE = 'github2'
    STORAGESERVICE = 'local'

    // repo
    GITHUB_URL  = "https://github.com/ito-takeshi-01/understand_test"

    // Git Bash
    GIT_BASH_PATH = "C:\\Program Files\\Git\\bin\\bash.exe"

    // proxy (必要なら)
    http_proxy = 'http://proxy.mei.co.jp:8080/'
    https_proxy = 'http://proxy.mei.co.jp:8080/'
    PROXY_HOST = "proxy.mei.co.jp"
    PROXY_PORT = "8080"

    // 使っていないなら残しても害はありません
    UND_CMD = "und -proxyhost ${PROXY_HOST} -proxyport ${PROXY_PORT} -proxycreds \"\""
  }

  options {
    buildDiscarder logRotator(numToKeepStr: '3')
  }

  stages {

    stage('Checkout') {
      agent any
      steps {
        checkout scm
      }
    }

    stage('Configure Understand Proxy') {
      agent { label 'understand' }
      steps {
        echo "Configuring Understand global settings for proxy..."
        bat """
          @echo off
          set GLOBAL_INI=%APPDATA%\\SciTools\\conf\\Understand\\global.ini
          if not exist "%APPDATA%\\SciTools\\conf\\Understand" mkdir "%APPDATA%\\SciTools\\conf\\Understand"

          echo [Proxy] > "%GLOBAL_INI%"
          echo Host=${PROXY_HOST} >> "%GLOBAL_INI%"
          echo Port=${PROXY_PORT} >> "%GLOBAL_INI%"
          echo Credentials= >> "%GLOBAL_INI%"

          echo --- Global.ini content ---
          type "%GLOBAL_INI%"
        """
      }
    }

    stage('Manual Build Setup') {
      agent any
      when {
        expression { params.BUILD_TYPE != 'NONE' }
      }
      steps {
        script {
          def branchToCheckout = ''
          if (params.BUILD_TYPE == 'MASTER') {
            branchToCheckout = 'master'
          } else if (params.BUILD_TYPE == 'FEATURE') {
            branchToCheckout = params.FEATURE_BRANCH_NAME
          }

          echo "Manual build triggered for branch: ${branchToCheckout}"

          checkout([
            $class: 'GitSCM',
            branches: [[name: "*/${branchToCheckout}"]],
            userRemoteConfigs: [[
              url: env.GITHUB_URL,
              credentialsId: 'GitHub-Understand5'
            ]]
          ])

          // 後続でwhen条件に使う
          env.BRANCH_NAME = branchToCheckout
        }
      }
    }

    stage('Baseline Analysis (master branch)') {
      agent { label 'understand' }
      when {
        anyOf {
          expression { env.BRANCH_NAME == 'master' && params.BUILD_TYPE == 'NONE' }
          expression { params.BUILD_TYPE == 'MASTER' }
        }
      }
      steps {
        echo "Master branch process starting..."
        bat """
          @echo off
          setlocal

          REM 保存先Windowsパスを bash用に変換して渡す: C:\\x\\y -> /c/x/y
          set WINP=${params.LOCAL_STORAGE_PATH}
          set BASH_P=%WINP:\\=/%
          set BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%
          set BASH_P=%BASH_P:~0,3%%BASH_P:~3%
          set LOCAL_STORAGE_PATH=%BASH_P%
          echo LOCAL_STORAGE_PATH(for bash)=%LOCAL_STORAGE_PATH%

          "${GIT_BASH_PATH}" -lc "./understand/analyze.sh --upload"
        """
      }
    }

    stage('Debug: Who am I') {
      steps {
         bat '''
          echo ==== ID Check (Windows cmd) ====
          whoami
          echo USERNAME=%USERNAME%
          echo USERPROFILE=%USERPROFILE%
          echo HOME=%HOME%
          echo HOMEDRIVE=%HOMEDRIVE%
          echo HOMEPATH=%HOMEPATH%
          echo ==== und ====
          where und
          und license
        '''
      }
    }

    stage('Comparison Analysis (feature branch)') {
      agent { label 'understand' }
      when {
        anyOf {
          // ポーリング（＝Multibranchスキャン起点）の場合
          expression { env.BRANCH_NAME != null && env.BRANCH_NAME != 'master' && params.BUILD_TYPE == 'NONE' }
          // 手動起動の場合
          expression { params.BUILD_TYPE == 'FEATURE' }
        }
      }
      steps {
        script {
          echo "Feature branch process starting for branch: ${env.BRANCH_NAME}..."
          withCredentials([string(credentialsId: 'GITHUB_CRED', variable: 'GITHUB_TOKEN_FROM_JENKINS')]) {
            bat """
              @echo off
              setlocal

              REM bashへ渡す変数
              set GITHUB_TOKEN=%GITHUB_TOKEN_FROM_JENKINS%
              set BRANCH_NAME=${env.BRANCH_NAME}

              REM 保存先Windowsパスを bash用に変換して渡す
              set WINP=${params.LOCAL_STORAGE_PATH}
              set BASH_P=%WINP:\\=/%
              set BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%
              set BASH_P=%BASH_P:~0,3%%BASH_P:~3%
              set LOCAL_STORAGE_PATH=%BASH_P%
              echo LOCAL_STORAGE_PATH(for bash)=%LOCAL_STORAGE_PATH%

              echo "--- 1. Analyzing current branch ---"
              "${GIT_BASH_PATH}" -lc "./understand/analyze.sh"

              echo "--- 2. Generating graphical report for PR ---"
              "${GIT_BASH_PATH}" -lc "./understand/generate-graphs.sh > review-comment.txt"

              echo "--- 3. Posting review comment to PR ---"
              "${GIT_BASH_PATH}" -lc "./understand/review-pr.sh review-comment.txt"
            """
          }
        }
      }
    }
  }

  post {
    always {
      node('understand') {
        echo "Always cleanup (on understand agent)..."
        bat """
          @echo off
          setlocal

          REM 保存先Windowsパスを bash用に変換して渡す（local.sh参照用）
          set WINP=${params.LOCAL_STORAGE_PATH}
          set BASH_P=%WINP:\\=/%
          set BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%
          set BASH_P=%BASH_P:~0,3%%BASH_P:~3%
          set LOCAL_STORAGE_PATH=%BASH_P%

          "${GIT_BASH_PATH}" -lc "./understand/clean.sh"
        """
      }
    }
  }
}


pipeline {
  agent none

  options {
    buildDiscarder(logRotator(numToKeepStr: '3'))
    timestamps()
    skipDefaultCheckout(true)
  }

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
    // Understand (Windows)
    UND_BIN_DIR = 'C:\\Program Files\\SciTools\\bin\\pc-win64'
    GIT_BASH_PATH = 'C:\\Program Files\\Git\\bin\\bash.exe'

    // repo
    GITHUB_URL = 'https://github.com/ito-takeshi-01/understand_test.git'

    // scripts selection
    GITSERVICE = 'github2'
    STORAGESERVICE = 'local'

    // proxy (必要なら)
    http_proxy  = 'http://proxy.mei.co.jp:8080/'
    https_proxy = 'http://proxy.mei.co.jp:8080/'
    PROXY_HOST = 'proxy.mei.co.jp'
    PROXY_PORT = '8080'
  }

  stages {
    stage('Checkout (controller)') {
      agent { label 'Jenkins' }   // controllerノードのラベルに合わせてください
      steps {
        checkout scm
      }
    }

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

          echo --- Global.ini content ---
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

          echo ==== ID Check (Windows cmd) ====
          whoami
          echo USERNAME=%USERNAME%
          echo USERPROFILE=%USERPROFILE%
          echo HOME=%HOME%
          echo HOMEDRIVE=%HOMEDRIVE%
          echo HOMEPATH=%HOMEPATH%

          echo ==== PATH (head) ====
          echo %PATH%

          echo ==== und ====
          set PATH=${UND_BIN_DIR};%PATH%
          where und
          und version
          und license
        """
      }
    }

    stage('Manual Build Setup (controller)') {
      agent { label 'Jenkins' }   // controllerノードのラベルに合わせてください
      when { expression { params.BUILD_TYPE != 'NONE' } }
      steps {
        script {
          def branchToCheckout = ''
          if (params.BUILD_TYPE == 'MASTER') {
            branchToCheckout = 'master'
          } else if (params.BUILD_TYPE == 'FEATURE') {
            branchToCheckout = params.FEATURE_BRANCH_NAME
          }
          echo "Manual build triggered for branch: ${branchToCheckout}"

          // “理解用”: このステージでBRANCH_NAMEだけ決める（SCM操作はagent側で統一して行う）
          env.TARGET_BRANCH = branchToCheckout
        }
      }
    }

    stage('Baseline Analysis (master)') {
      agent { label 'understand-agent' }
      when {
        anyOf {
          // Multibranch起動で master のとき
          expression { params.BUILD_TYPE == 'NONE' && (env.BRANCH_NAME == 'master' || env.GIT_BRANCH == 'origin/master') }
          // 手動指定で master のとき
          expression { params.BUILD_TYPE == 'MASTER' }
        }
      }
      steps {
        // 手動起動(master) の場合に備えて、agent側で master をチェックアウトし直す
        script {
          if (params.BUILD_TYPE == 'MASTER') {
            checkout([
              $class: 'GitSCM',
              branches: [[name: '*/master']],
              userRemoteConfigs: [[url: env.GITHUB_URL, credentialsId: 'GitHub-Understand5']]
            ])
          }
        }

        bat """
          @echo off
          setlocal

          set PATH=${UND_BIN_DIR};%PATH%

          REM 保存先Windowsパスを bash用に変換して渡す: C:\\x\\y -> /c/x/y
          set "WINP=${params.LOCAL_STORAGE_PATH}"
          set "BASH_P=%WINP:\\=/%"
          set "BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%"
          set "LOCAL_STORAGE_PATH=%BASH_P%"
          echo LOCAL_STORAGE_PATH(for bash)=%LOCAL_STORAGE_PATH%

          "${GIT_BASH_PATH}" -lc "./understand/analyze.sh --upload"
        """
      }
    }

    stage('Comparison Analysis (feature)') {
      agent { label 'understand-agent' }
      when {
        anyOf {
          // Multibranch起動で master 以外のとき
          expression { params.BUILD_TYPE == 'NONE' && env.BRANCH_NAME != null && env.BRANCH_NAME != 'master' }
          // 手動指定で feature のとき
          expression { params.BUILD_TYPE == 'FEATURE' }
        }
      }
      steps {
        // 手動起動(feature) の場合に備えて、agent側で対象ブランチをチェックアウト
        script {
          if (params.BUILD_TYPE == 'FEATURE') {
            checkout([
              $class: 'GitSCM',
              branches: [[name: "*/${params.FEATURE_BRANCH_NAME}"]],
              userRemoteConfigs: [[url: env.GITHUB_URL, credentialsId: 'GitHub-Understand5']]
            ])
            env.TARGET_BRANCH = params.FEATURE_BRANCH_NAME
          } else {
            // multibranch の通常ケース
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

            REM 保存先Windowsパスを bash用に変換して渡す
            set "WINP=${params.LOCAL_STORAGE_PATH}"
            set "BASH_P=%WINP:\\=/%"
            set "BASH_P=/%BASH_P:~0,1%/%BASH_P:~2%"
            set "LOCAL_STORAGE_PATH=%BASH_P%"
            echo LOCAL_STORAGE_PATH(for bash)=%LOCAL_STORAGE_PATH%

            echo --- 1. Analyzing current branch ---
            "${GIT_BASH_PATH}" -lc "./understand/analyze.sh"

            echo --- 2. Generating graphical report for PR ---
            "${GIT_BASH_PATH}" -lc "./understand/generate-graphs.sh > review-comment.txt"

            echo --- 3. Posting review comment to PR ---
            "${GIT_BASH_PATH}" -lc "./understand/review-pr.sh review-comment.txt"
          """
        }
      }
    }
  }

  post {
    always {
      agent { label 'understand-agent' }
      steps {
        bat """
          @echo off
          setlocal

          set PATH=${UND_BIN_DIR};%PATH%

          REM 保存先Windowsパスを bash用に変換して渡す（local.sh参照用）
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
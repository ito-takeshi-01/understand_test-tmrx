pipeline {
  agent any

  // 手動実行時に条件を制御できるようにする
  
  // 15分ごとにGitリポジトリの変更をチェックするポーリング設定
  triggers {
    pollSCM('H/15 * * * *')
  }

  parameters {
    // booleanParam(name: 'RUN_ALWAYS', defaultValue: false, description: '常にこのパイプラインを実行する')
    choice(
        name: 'BUILD_TYPE',
        choices: ['NONE', 'MASTER', 'FEATURE'],
        description: '手動で実行するビルドの種類を選択します。NONEの場合はSCMポーリングでのみ動作します。'
    )
    string(
        name: 'FEATURE_BRANCH_NAME',
        defaultValue: 'develop', // デフォルトのテスト用ブランチ名
        description: 'BUILD_TYPEでFEATUREを選択した場合に、対象となるブランチ名を入力します。'
    )
  }

  environment {
    PATH = "C:\\Program Files\\SciTools\\bin\\pc-win64;${env.PATH}"
    GITSERVICE = 'github2'
    //GITHUB_CRED = credentials('GITHUB_CRED')                               // JenkinsのCredential設定より、GitHubの資格情報IDを取得する
                                                                           //  (※予めJenkinsの設定＞Crdentialで設定が必要、またCredentialのIDの名称を同じ(例 GITHUB_CRED)にする必要あり)
    GITHUB_URL  = "https://github.com/ito-takeshi-01/understand_test"      // GitHubリポジトリ設定 　 ※個別に設定が必要
    STORAGESERVICE = 'local'                                               // ストレージサービスの設定
    LOCAL_STORAGE_PATH = "C:\\work\\understand_data\\test_prj"             // ローカルストレージ設定 　※個別に設定が必要
    
    // Git Bashのパスと作業ディレクトリ
    GIT_BASH_PATH = "C:\\Program Files\\Git\\bin\\bash.exe"                // ※個別に設定が必要
    //WORK_DIR = "/c/jenkins/workspace/workspace/understand/test_pipeline2"  // 実際のパスに置き換えが必要
    
    //set networking proxy
    http_proxy ='http://proxy.mei.co.jp:8080/'
    https_proxy='http://proxy.mei.co.jp:8080/'
    
    // プロキシサーバーの情報を環境変数として定義
    PROXY_HOST = "proxy.mei.co.jp"
    PROXY_PORT = "8080"
    
    // プロキシ設定を含んだ `und` コマンドのエイリアスを定義
    // bash スクリプト内で `und` と呼び出すと、これが実行される
    // -proxycreds "" を追加して不要な認証ダイアログを抑制する
    UND_CMD = "und -proxyhost ${PROXY_HOST} -proxyport ${PROXY_PORT} -proxycreds \"\"" 
  }

  // 過去n回のビルドログを保持し、古いログを自動的に削除
  options {
    buildDiscarder logRotator(numToKeepStr: '3')
  }

  stages {
    stage('Configure Understand Proxy') {
      steps {
        script {
          echo "Configuring Understand global settings for proxy..."
          bat """
            @echo off
            REM Understandのグローバル設定ファイルのパスを取得 (通常は %APPDATA%\\SciTools\\conf\\Understand\\global.ini)
            set GLOBAL_INI=%APPDATA%\\SciTools\\conf\\Understand\\global.ini

            REM 設定ファイル用のディレクトリが存在しない場合に作成
            if not exist "%APPDATA%\\SciTools\\conf\\Understand" mkdir "%APPDATA%\\SciTools\\conf\\Understand"

            REM グローバル設定ファイルにプロキシ設定を書き込む
            echo [Proxy] > "%GLOBAL_INI%"
            echo Host=${PROXY_HOST} >> "%GLOBAL_INI%"
            echo Port=${PROXY_PORT} >> "%GLOBAL_INI%"
            echo Credentials= >> "%GLOBAL_INI%"

            echo --- Global.ini content ---
            type "%GLOBAL_INI%"
            @echo on
          """
        }
      }
    }
  
    // === Stage 0: 手動実行時のセットアップ ===
    stage('Manual Build Setup') {
      when {
        // BUILD_TYPE が NONE ではない (手動実行が選択された) 場合にのみ実行
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

          // 手動実行の場合、Declarative Checkoutはスキップされるため、指定されたブランチを明示的にチェックアウトする
          checkout([
            $class: 'GitSCM',
            branches: [[name: "*/${branchToCheckout}"]],
            userRemoteConfigs: [[
              url: env.GITHUB_URL,
              // このパイプラインジョブでGitリポジトリにアクセスするための資格情報ID
              // (例) GitHub-Understand5。必要に応じて変更してください。
              credentialsId: 'GitHub-Understand5' 
            ]]
          ])
          
          // 後続のステージで参照できるよう、env.BRANCH_NAME を手動で設定する
          env.BRANCH_NAME = branchToCheckout
        }
      }
    }

    // === Stage 1: masterブランチでの処理 (ベースライン解析と保存) ===
    stage('Baseline Analysis (master branch)') {
      when {
        // 条件: [通常のポーリングでmasterブランチを検出] または [手動でMASTERが選択された]
        anyOf {
          // ポーリング時はJenkinsが自動でチェックアウトし、env.BRANCH_NAMEを設定する
          expression { env.BRANCH_NAME == 'master' && params.BUILD_TYPE == 'NONE' } 
          // 手動実行時はパラメータで判断
          expression { params.BUILD_TYPE == 'MASTER' }
        }
      }
      steps {
        script {
          echo "Master branch process starting..."
          // analyze.sh を --upload オプション付きで実行し、解析結果をベースラインとして保存
          bat """
          @echo off
          echo --- Current PATH in Baseline Stage ---
          echo %PATH%
          @echo on
          
          echo ==== und license (from Jenkins) ====
          und license
          echo ==== und help (from Jenkins) ====
          und help
          echo ==================================
          
          "${GIT_BASH_PATH}" -c "./understand/analyze.sh --upload"
          """
        }
      }
    }

    // === Stage 2: PR/featureブランチでの処理 (比較解析とレポート) ===
    stage('Comparison Analysis (feature branch)') {
      when {
        // 条件: [通常のポーリングでmaster以外のブランチを検出] または [手動でFEATUREが選択された]
        anyOf {
          // ポーリング時
          expression { env.BRANCH_NAME != null && env.BRANCH_NAME != 'master' && params.BUILD_TYPE == 'NONE' }
          // 手動実行時
          expression { params.BUILD_TYPE == 'FEATURE' }
        }
      }
      steps {
        script {
          echo "Feature branch process starting for branch: ${env.BRANCH_NAME}..."
          // GitHub APIを使用するため、withCredentialsで資格情報を安全に渡す
          withCredentials([string(credentialsId: 'GITHUB_CRED', variable: 'GITHUB_TOKEN_FROM_JENKINS')]) {
            bat(script: """
              @echo off
              
              REM 後続のbashスクリプトで使えるように環境変数をセット
              set GITHUB_TOKEN=%GITHUB_TOKEN_FROM_JENKINS%
              set BRANCH_NAME=${env.BRANCH_NAME}
              
              echo "--- 1. Analyzing current branch ---"
              REM 増分解析のため、現在のブランチのDBを作成 (アップロードはしない)
              "${GIT_BASH_PATH}" -c "./understand/analyze.sh"
              
              echo "--- 2. Generating graphical report for PR ---"
              REM 解析DBを比較し、差分レポート(review-comment.txt)を作成
              REM このスクリプト内でGitHub APIを叩き、PR情報を取得する
              "${GIT_BASH_PATH}" -c "./understand/generate-graphs.sh > review-comment.txt"
              
              echo "--- 3. Posting review comment to PR ---"
              REM 作成したレポートをGitHubのPRにコメントとして投稿
              "${GIT_BASH_PATH}" -c "./understand/review-pr.sh review-comment.txt"
            """)
          }
        }
      }
    }
  }


  post {
    cleanup {
      script {
        // 最後のビルドで作成された一時ファイルをクリーンアップする
        echo "Cleaning up workspace..."
        bat """
        @echo off
        echo --- Current PATH in Cleanup Stage ---
        echo %PATH%
        @echo on
        
        "${GIT_BASH_PATH}" -c "./understand/clean.sh"
        """
      }
    }
  }

}


pipeline {
  agent {
    // Windows用のエージェントラベルに変更
    label 'windows && understand'
  }

  // 手動実行時に条件を制御できるようにする
  parameters {
    booleanParam(name: 'RUN_ALWAYS', defaultValue: false, description: '常にこのパイプラインを実行する')
  }

  environment {
    GITSERVICE = 'github2'
    GITHUB_CRED = credentials('GITHUB_CRED')                          // JenkinsのCredential設定より、GitHubの資格情報IDを取得する
                                                                      //  (※予めJenkinsの設定＞Crdentialで設定が必要、またCredentialのIDの名称を同じ(例 GITHUB_CRED)にする必要あり)
    GITHUB_URL  = "https://github.com/ito-takeshi-01/understand_test" // GitHubリポジトリ設定 　 ※個別に設定が必要
    STORAGESERVICE = 'local'                                          // ストレージサービスの設定
    LOCAL_STORAGE_PATH = "C:\\work\\understand_data\\test_prj"          // ローカルストレージ設定 　※個別に設定が必要
  }

  // 過去n回のビルドログを保持し、古いログを自動的に削除
  options {
    buildDiscarder logRotator(numToKeepStr: '5')
  }

  stages {
    stage('Analysis') {
      //メインブランチにプッシュされたまたはメインブランチへマージするプルリクストが発行された場合に実行する
      when {
        anyOf { 
          branch 'master'                  // GitHubのブランチがmasterの場合
          changeRequest target: 'master'   // PRのターゲットがmasterの場合
          expression { params.RUN_ALWAYS } // 手動実行時に常に実行
        }
      }
      steps {
        // Windows PowerShellを使用
        powershell '''
        Write-Output $Env:PATH
        bash ./understand/analyze.sh --upload
        '''
      }
    }
    stage('Pull Request Review') {
      when {
        changeRequest target: 'master'   // PRのターゲットがmasterの場合
        expression { params.RUN_ALWAYS } // 手動実行時に常に実行
      }
      steps {
        powershell '''
        bash ./understand/generate-graphs.sh > review-comment.txt
        bash ./understand/review-pr.sh review-comment.txt
        '''
      }
    }
  }
  post {
    cleanup {
      powershell './understand/clean.sh'
    }
  }
}


pipeline {
  agent {
    // Windows用のエージェントラベルに変更
    label 'windows && understand'
  }

  environment {
    GITSERVICE = 'github2'
    GITHUB_CRED = credentials('GITHUB_CRED')                          // JenkinsのCredential設定より、GitHubの資格情報IDを取得する
                                                                      //  (※予めJenkinsの設定＞Crdentialで設定が必要、またCredentialのIDの名称を同じ(例 GITHUB_CRED)にする必要あり)
    GITHUB_URL  = "https://github.com/ito-takeshi-01/understand_test" // GitHubリポジトリ設定 　 ※個別に設定が必要
    STORAGESERVICE = 'local'                                          // ストレージサービスの設定
    LOCAL_STORAGE_PATH = "C:\\work\\understand_data\\test_prj"          // ローカルストレージ設定 　※個別に設定が必要
  }

  options {
    buildDiscarder logRotator(numToKeepStr: '10')
  }

  stages {
    stage('Analysis') {
      //メインブランチにプッシュされたまたはメインブランチへマージするプルリクストが発行された場合に実行する
      when {
        anyOf { 
          branch 'main'
          changeRequest target: 'main'
        }
      }
      steps {
        // Windows PowerShellを使用
        powershell '''
        env:PATH
        ./understand/analyze.sh --upload
        '''
      }
    }
    stage('Pull Request Review') {
      when {
        changeRequest target: 'main'
      }
      steps {
        powershell '''
        ./understand/generate-graphs.sh > review-comment.txt
        ./understand/review-pr.sh review-comment.txt
        '''
      }
    }
  }
  post {
    cleanup {
      powershell './understand/clean.ps1'
    }
  }
}


// Test PR analysis

#include <stdio.h>

int main(void) {
    int n;

    printf("1-100の数値を入力してください: ");

    // 標準入力から1つの整数を読み取る
    if (scanf("%d", &n) != 1) {
        fprintf(stderr, "入力エラー: 整数を入力してください。\n");
        return 1;
    }

    // 入力が1?100の範囲内かをチェック
    if (n < 1 || n > 100) {
        printf("入力値は1から100の範囲内でなければなりません。\n");
        return 0;
    }

    // グループ分け
    if (n <= 25) {
        printf("グループＡ\n");
    } else if (n <= 50) {
        printf("グループＢ\n");
    } else if (n <= 75) {
        printf("グループＣ\n");
    } else {
        printf("グループＤ\n");
    }

    return 0;
}
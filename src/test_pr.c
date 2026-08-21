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
    if (n <= 20) {
        printf("グループＡ\n");
    } else if (n <= 40) {
        printf("グループＢ\n");
    } else if (n <= 75) {
        printf("グループＣ\n");
    } else {
        printf("グループＤ\n");
    }

    return 0;
}

void final_test_function(int value) {
    if (value > 50) {
        printf("Success: Value is %d\n", value);
    } else {
        printf("Failed: Value is %d\n", value);
    }
}


int calculate_sum(int a, int b) {
    return a + b;
}

int calculate_product(int x, int y) {
    return x * y;
}

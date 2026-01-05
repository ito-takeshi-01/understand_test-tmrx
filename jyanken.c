/* sample code */
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>
#include <time.h>

int main(){
	int key = 0;
	int com = 0;
	int count = 0;
	int score1 = 0;
	int score2 = 0;
	int score3 = 0;
	int score4 = 0;

	srand((unsigned)time(NULL));

	for(count=5;count>0;count--){ 
		printf("勝ち%d回　負け%d回　引き分け%d回　ノーカウント%d回　残り回数%d回\n",score1,score2,score3,score4,count);
		printf("何を出しますか？１・グー　２・チョキ　３・パー\n");
		printf("番号を入れてください > ");

		key = _getche();
		if(key == 0 || key == 224)key = _getche();

		com = (rand() % 3 + 49);

		if(key > 48 && key < 52){
			printf("\n");
			printf("私の手 : ");
			switch(key){
			case 49:
				printf("グー");
				break;
			case 50:
				printf("チョキ");
				break;
			case 51:
				printf("パー");
				break;
			default:
				break;
			}
			printf("・");
			printf("comの手 : ");
			switch(com){
			case 49:
				printf("グー");
				break;
			case 50:
				printf("チョキ");
				break;
			case 51:
				printf("パー");
				break;
			default:
				break;
			}
			printf("・");
			printf("結果 : ");
			if(key == com){
				printf("あいこ");
				score3++;
			}
			else if(key==49 && com==51){
				printf("comの勝ち");
				score2++;
			}
			else if(key==50 && com==49){
				printf("comの勝ち");
				score2++;
			}
			else if(key==51 && com==50){
				printf("comの勝ち");
				score2++;
			}
			else{
				printf("私の勝ち");
				score1++;
			}
		}
		else{
			printf("\n");
			printf("１か２か３を選んでね！");
			score4++;
		}
		printf("\n\n");
	}

	printf("結果発表\n");
	printf("勝ち%d回　負け%d回　引き分け%d回　ノーカウント%d回　残り回数%d回\n",score1,score2,score3,score4,count);

	return 0;
}
/*************************************************************************
    > File Name: pointer_test.c
    > Author: raoqiyu
    > Mail: raoqiyu@gmail.com 
    > Created Time: 2018年05月15日 星期二 15时09分42秒
 ************************************************************************/

#include<stdio.h>
int main(){
	int a = 3;
	int *b = &a;
	int **c = &b;
	printf("a,b,c三个变量的地址-> &a: %d, &b: %d, &c: %d\n", &a, &b, &c);
	printf("a,b,c三个变量的值-> a: %d, b: %d, c: %d.\n", a,b,c);
	printf("b,c是指针，可以取出值所代表的地址中的值-> *b: %d, *c: %d.\n",*b,*c);
	printf("c是二级指针，可以二级连跳-> **c: %d.\n", **c);
	
	printf("b中的值是a的地址，*b可以返回a的值\n");
	printf("c中的值是b的地址，*c可以返回b的值；**c可以返回*b的值，也就是*b的值\n");
	
	
	return 0;
}

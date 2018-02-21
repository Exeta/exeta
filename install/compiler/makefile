exeta : exeta.tab.c lex.yy.c
	gcc -o exeta exeta.tab.c lex.yy.c

exeta.tab.h exeta.tab.c : exeta.y
	bison -v -r 'all' -d exeta.y

lex.yy.c : exeta.l exeta.tab.h
	flex exeta.l

install :
	mv exeta ${EXETA_HOME}/bin

clean :
	rm exeta.tab.h exeta.tab.c lex.yy.c exeta.output


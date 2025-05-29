
CC = gcc
CFLAGS = -Wall
LDFLAGS = 

RM = rm -f

all: gensudokuconstr

gensudokuconstr: gensudokuconstr.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ 

clean:
	$(RM) gensudokuconstr *.eps *~



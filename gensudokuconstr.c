// Code is GPLed, original script by Marko Riedel,
// markoriedelde@gmail.com

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>

#define INITIALRUN 20

#define LINE (9+8+1)

typedef struct {
  unsigned int data[9][9];
  struct { int set[9]; int size; } constr[9][9];
} board, *boardPtr;

board solution;

enum { GENERATE = 0, SOLVEUNIQ, SOLVE } solvemode = 0;

int guesswork = 1;
int backtracked[9][9];

int backtrackednodes(void)
{
  int row, col, nodes = 0;

  for(row=0; row<9; row++)
    for(col=0; col<9; col++)
      if(backtracked[row][col] >= 2)
	nodes++;

  return nodes;
}
      
int solfound = 0;
int clues = 30;

void printboard(boardPtr bp)
{
  int row, col;

  for(row=0; row<9; row++)
    for(col=0; col<9; col++){
      printf("%d", bp->data[row][col]);
      putchar(col<8 ? ' ' : '\n');
    }  
}

void initconstr(boardPtr bp)
{
  int row, col, val;

  for(row=0; row<9; row++)
    for(col=0; col<9; col++){
      for(val=0; val<9; val++){
	bp->constr[row][col].set[val] = 1;
	bp->constr[row][col].size = 9;
      }
    }
}

void updateconstr(int x, int y, int val,
		  boardPtr bp)
{
  int row, col, clustX, clustY;

  for(row=0; row<9; row++)
    if(row !=x && bp->constr[row][y].set[val-1] == 1){
      bp->constr[row][y].set[val-1] = 0;
      bp->constr[row][y].size--;
    }

  for(col=0; col<9; col++)
    if(col !=y && bp->constr[x][col].set[val-1] == 1){
      bp->constr[x][col].set[val-1] = 0;
      bp->constr[x][col].size--;
    }

  clustX = x/3; clustY = y/3;
  for(row=0; row<3; row++)
    for(col=0; col<3; col++){
      int xx = clustX*3+row, yy = clustY*3+col;

      if(xx != x && yy != y &&
	 bp->constr[xx][yy].set[val-1] == 1){
	bp->constr[xx][yy].set[val-1] = 0;
	bp->constr[xx][yy].size--;
      }
    }
}

void updateallconstr(boardPtr bp)
{
  for(int row=0; row<9; row++)
    for(int col=0; col<9; col++){
      int val = bp->data[row][col];
      if(val>0)
	updateconstr(row, col, val, bp);
    }
}

int isconsistent(int x, int y, boardPtr bp)
{
  unsigned int row, col, clustX, clustY;
  int val = bp->data[x][y];
  
  for(row=0; row<9; row++){
    if(bp->data[row][y] == val && row !=x)
      return 0;
  }

  for(col=0; col<9; col++){
    if(bp->data[x][col] == val && col !=y)
      return 0;
  }
  
  clustX = x/3; clustY = y/3;
  for(row=0; row<3; row++)
    for(col=0; col<3; col++){
      int xx = clustX*3+row, yy = clustY*3+col;
      if(bp->data[xx][yy] == val &&
	 (xx != x || yy != y))
	return 0;
    }

  return 1;
}

void singleton(int *xp, int *yp, int *singp, boardPtr bp)
{
  int val, seen, x, y;
  unsigned int row, col, clustX, clustY;

  for(val=1; val<=9; val++){
    for(row=0; row<9; row++){
      seen = 0;
      
      for(col=0; col<9; col++)
	if(bp->data[row][col] == 0 &&
	   bp->constr[row][col].set[val-1] == 1){
	  seen++; x = row; y = col;
	}

      if(seen == 1){ *singp = val;
	*xp = x; *yp = y; return; };
    }

    for(col=0; col<9; col++){
      seen = 0;
      
      for(row=0; row<9; row++)
	if(bp->data[row][col] == 0 &&
	   bp->constr[row][col].set[val-1] == 1){
	  seen++; x = row; y = col;
	}

      if(seen == 1){ *singp = val;
	*xp = x; *yp = y; return; };
    }
    
    for(clustX = 0; clustX<3; clustX++)
      for(clustY = 0; clustY<3; clustY++){
	seen = 0;

	int xx, yy;
	for(row=0; row<3; row++)
	  for(col=0; col<3; col++){
	    xx = clustX*3+row; yy = clustY*3+col;
	    if(bp->data[xx][yy] == 0 &&
	       bp->constr[xx][yy].set[val-1] == 1){
	      seen++; x = xx; y = yy;
	    }
	  }

	if(seen == 1){ *singp = val;
	  *xp = x; *yp = y; return; };
      }
  }

  return;
}

int recurse(boardPtr bp, int placed){
  if(placed == 81){
    memcpy(&solution, bp, sizeof(board));
    solfound++;

    if(solvemode == SOLVE && solfound > 1){
      puts("NOTUNIQUE");
      exit(2);
    }

    return (solfound > 1 ? 2 : 0);
  }

  int nx=-1, ny=-1, row, col, size = 10;
  
  for(row=0; row<9; row++)
    for(col=0; col<9; col++){
      int val = bp->data[row][col];
      if(val == 0){
	int sz = bp->constr[row][col].size;
	if(sz < size){
	  nx = row; ny = col;
	  size = sz;
	}
      }
    }

  if(size > 1){
    int single = -1;
    singleton(&nx, &ny, &single, bp);

    if(single != -1){
      board nxt; memcpy(&nxt, bp, sizeof(board));
      
      nxt.data[nx][ny] = single;
      updateconstr(nx, ny, single, &nxt);
      
      return recurse(&nxt, placed+1);
    }
  }
    
  if(!guesswork && size > 1) return 0;

  for(int val=0; val<9; val++){
    if(bp->constr[nx][ny].set[val] == 1){
      backtracked[nx][ny]++;
      
      board nxt; memcpy(&nxt, bp, sizeof(board));
      
      nxt.data[nx][ny] = val+1;
      updateconstr(nx, ny, val+1, &nxt);
      
      int retval = recurse(&nxt, placed+1);
      if(retval) return retval;
    }
  }
  
  return 0;
}

int permutation[9];

void genperm(int n)
{
  int pos;

  for(pos=0; pos<n; pos++) permutation[pos] = pos;

  for(int idx = n; idx>1; idx--){
    int choice = rand() % idx, tmp;

    if(choice < idx-1){
      tmp = permutation[idx-1];
      permutation[idx-1] = permutation[choice];
      permutation[choice] = tmp;
    }
  }
}

void rowcolperm(int *lp)
{
  for(int lidx=0; lidx<3; lidx++){
    genperm(3);
    for(int q=0; q<3; q++){
      lp[lidx*3+q] = lidx*3+permutation[q];
    }
  }
}

struct { int data[9][9]; } btypes[4] =
  {
    { { { 5, 6, 8, 7, 4, 1, 3, 9, 2 },
	{ 2, 4, 7, 3, 5, 9, 8, 6, 1 },
	{ 3, 1, 9, 6, 8, 2, 7, 5, 4 },
	{ 9, 3, 6, 2, 7, 4, 5, 1, 8 },
	{ 4, 2, 5, 8, 1, 3, 6, 7, 9 },
	{ 7, 8, 1, 5, 9, 6, 4, 2, 3 },
	{ 6, 5, 3, 9, 2, 8, 1, 4, 7 },
	{ 1, 7, 2, 4, 3, 5, 9, 8, 6 },
	{ 8, 9, 4, 1, 6, 7, 2, 3, 5 },
      } },
    { { { 7, 5, 8, 9, 6, 4, 2, 3, 1 },
	{ 2, 1, 9, 7, 5, 3, 4, 6, 8 },
	{ 4, 3, 6, 2, 8, 1, 5, 7, 9 },
	{ 8, 7, 4, 3, 1, 2, 9, 5, 6 },
	{ 1, 9, 3, 6, 4, 5, 7, 8, 2 },
	{ 5, 6, 2, 8, 7, 9, 1, 4, 3 },
	{ 9, 8, 1, 4, 3, 7, 6, 2, 5 },
	{ 6, 4, 5, 1, 2, 8, 3, 9, 7 },
	{ 3, 2, 7, 5, 9, 6, 8, 1, 4 }
      } },
    { { { 5, 7, 4, 2, 8, 3, 6, 9, 1 },
	{ 9, 2, 3, 5, 1, 6, 8, 7, 4 },
	{ 6, 1, 8, 9, 7, 4, 3, 2, 5 },
	{ 2, 8, 7, 4, 9, 1, 5, 3, 6 },
	{ 1, 6, 5, 3, 2, 8, 9, 4, 7 },
	{ 3, 4, 9, 6, 5, 7, 1, 8, 2 },
	{ 7, 3, 1, 8, 4, 5, 2, 6, 9 },
	{ 4, 9, 6, 1, 3, 2, 7, 5, 8 },
	{ 8, 5, 2, 7, 6, 9, 4, 1, 3 }
      } },
    { { { 8, 7, 9, 4, 3, 1, 6, 2, 5 },
	{ 3, 5, 2, 9, 6, 8, 7, 4, 1 },
	{ 4, 6, 1, 7, 2, 5, 3, 8, 9 },
	{ 2, 3, 8, 5, 1, 9, 4, 7, 6 },
	{ 6, 4, 5, 8, 7, 3, 9, 1, 2 },
	{ 1, 9, 7, 6, 4, 2, 8, 5, 3 },
	{ 9, 2, 6, 1, 8, 4, 5, 3, 7 },
	{ 5, 1, 4, 3, 9, 7, 2, 6, 8 },
	{ 7, 8, 3, 2, 5, 6, 1, 9, 4 }
      } }
  };

int boardtype = 1;

void generate(boardPtr bp)
{
  int row, col, clustX, clustY;

  int nxt[9][9], data[9][9];
  memcpy(&data, &(btypes[boardtype-1].data), sizeof(data));

  int lperm[9];

  rowcolperm(lperm);
  for(row=0; row<9; row++)
    for(col=0; col<9; col++)
      nxt[row][col] = data[lperm[row]][col];
  memcpy(&data, &nxt, sizeof(data));
  
  rowcolperm(lperm);
  for(row=0; row<9; row++)
    for(col=0; col<9; col++)
      nxt[row][col] = data[row][lperm[col]];
  memcpy(&data, &nxt, sizeof(data));
  
  genperm(3);
  for(clustX=0; clustX<3; clustX++)
    for(clustY=0; clustY<3; clustY++)
      for(int x=0; x<3; x++)
	for(int y=0; y<3; y++){
	  row = clustX*3+x;
	  col = clustY*3+y;
	  int row2 = permutation[clustX]*3+x;
	  
	  nxt[row][col] = data[row2][col];
	}
  memcpy(&data, &nxt, sizeof(data));

  genperm(3);
  for(clustX=0; clustX<3; clustX++)
    for(clustY=0; clustY<3; clustY++)
      for(int x=0; x<3; x++)
	for(int y=0; y<3; y++){
	  row = clustX*3+x;
	  col = clustY*3+y;
	  int col2 = permutation[clustY]*3+y;
	  
	  nxt[row][col] = data[row][col2];
	}
  memcpy(&data, &nxt, sizeof(data));
  
  genperm(9);
  for(row=0; row<9; row++)
    for(col=0; col<9; col++)
      data[row][col] =
	1+permutation[data[row][col]-1];
  
  memcpy(&(bp->data), &data, sizeof(data));
}

int main(int argc, char **argv)
{
  int ochr;
  long int seed = 1; int secs = 0;

  while((ochr = getopt(argc, argv, "sgxt:r:c:y:")) != -1)
    switch(ochr) {
    case 's': solvemode = SOLVE; break;
    case 'g': solvemode = GENERATE; break;
    case 'x': guesswork = 0; break;
    case 't': secs = atoi(optarg); break;
    case 'r': seed = atoi(optarg); break;
    case 'c': clues = atoi(optarg); break;
    case 'y': boardtype = atoi(optarg); break;
    default: exit(-1);
    };

  assert(seed >= 1);
  assert(secs >= 0);
  assert(81 >= clues && clues >= 20);
  assert(4 >= boardtype && boardtype >= 1);
  
  srand(seed);

  board binst;
  memset(&binst, 0, sizeof(board));
  
  int placed = 0;
  if(solvemode){
    for(int line=0; line<9; line++){
      char linestr[LINE+1];
      memset(linestr, 0, (LINE+1)*sizeof(char));

      assert(fgets(linestr, LINE+1, stdin) == linestr);
      assert(strlen(linestr) == LINE);

      for(int pos=0; pos<2*9; pos+=2){
	char val[2] = { linestr[pos], 0};
	char sep = linestr[pos+1];

	assert(isdigit(val[0]));
	assert(sep == (pos == 2*8 ? '\n' : ' '));
	binst.data[line][pos/2] = atoi(val);
      }
    }

    for(int row=0; row<9; row++)
      for(int col=0; col<9; col++){
    	int val = binst.data[row][col];
    	if(val > 0 && !isconsistent(row, col, &binst)){
    	  puts("NOSOLUTIONCONST");
    	  exit(3);
    	}
	else if(val > 0)
	  placed++;
      }

    initconstr(&binst);
    updateallconstr(&binst);
  }

  if(solvemode){
    recurse(&binst, placed);

    if(solfound != 1){
      puts("NOSOLUTION");
      exit(4);
    }

    printboard(&solution);
  }
  else{
    long attempts = 0;

    long start = time(NULL); long nxtcheck = INITIALRUN;
    while(1){
      if(secs > 0){
	if(attempts == nxtcheck){
	  long now = time(NULL); long elapsed = now - start;
	  if(!elapsed){
	    nxtcheck *= 2;
	  }
	  else{
	    double avgdur
	      = (double)elapsed/(double)attempts;
	    double remain = secs - elapsed;

	    if(elapsed >= secs || remain <= avgdur){
	      puts("TIMEOUT");
	      exit(1);
	    }	  
	  
	    long rem = (long)(remain/avgdur);
	    if(rem > nxtcheck) rem = nxtcheck;
	    nxtcheck += rem;
	  }
	}
      }
            
      memset(&binst, 0, sizeof(board));
      initconstr(&binst);
      
      solfound = 0; solvemode = GENERATE;
      board xsol;
      generate(&xsol);

      board mask; memset(&mask, 0, sizeof(mask));
      struct { int x, y; } pos[81], *posptr = pos;
      for(int row=0; row<9; row++)
	for(int col=0; col<9; col++){
	  posptr->x = row; posptr->y = col;
	  posptr++;
	}

      int seen[9]; memset(&seen, 0, sizeof(seen));
      
      for(int cluex = clues, avail = 81;
	  cluex>=1; cluex--){
	int choice = rand() % avail;
	int row = pos[choice].x, col = pos[choice].y;
	
	int valchoice = xsol.data[row][col];
	mask.data[row][col] = valchoice;
	seen[valchoice-1]++;
	
	for(int q=choice; q<avail-1; q++)
	  pos[q] = pos[q+1];
	avail--;
      }

      int val;
      for(val=0; val<9; val++)
	if(seen[val] == 0) break;

      if(val<9) continue;
      
      board maskcp; memcpy(&maskcp, &mask, sizeof(board));
      initconstr(&maskcp);
      updateallconstr(&maskcp);
      
      memset(&backtracked, 0, sizeof(backtracked));
      
      solfound = 0; solvemode = SOLVEUNIQ;
      recurse(&maskcp, clues);
      
      int btrack = backtrackednodes();
      attempts++;
      
      if(solfound == 1 &&
	 (!guesswork || btrack >= (81-clues)/5 )){
	printf("SimpleSudoku 0 -1 1 1 %d\n", guesswork);
	printboard(&xsol);
	fprintf(stderr, "ATTEMPTS %ld %d\n", attempts, btrack);
	printboard(&mask);
	break;
      }
    }
  }

  
  exit(0);
}

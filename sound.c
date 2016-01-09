# include <stdio.h>
char* notes1 = "BY}6YB6%";
char* notes2 = "Qj}6jQ6%";
int getNote(int time, int x, int position, int instrument){
  int   selection = 3 & time >> 16;
  char* selected  = selection ? "BY}6YB6%":"Qj}6jQ6%";
  int   baseNote  = selected[position % 8] + 51;
  int   note      = (baseNote * time) >> instrument;
  int   result    = 3 & x & note;
  return (result << 4);
}

int main(int i, int n, int s){
  for(i=0;;i++){
    int n    = i >> 14;
    int s    = i >> 17;
    int ins1 = getNote(i, 1,     n,                  12);
    int ins2 = getNote(i, s,     n^i>>13,            10);
    int ins3 = getNote(i, s/3,   n + ((i>>11)%3),    10);
    int ins4 = getNote(i, s/5,   8 + n -((i>>10)%3), 9);
    int combined = ins1 + ins2 + ins3 + ins4;
    putchar(combined);
  }
}

/* Unix */
#include <stdio.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>

/* http://stackoverflow.com/questions/30279228/is-there-an-alternative-to-getcwd-in-fortran-2003-2008 */


int isdirectory_c(const char *dir){
  struct stat statbuf;
  if(stat(dir, &statbuf) != 0)                                                                      /* error */
    return 0;                                                                                       /* return "NO, this is not a directory" */
  return S_ISDIR(statbuf.st_mode);                                                                  /* 1 => is directory, 0 => this is NOT a directory */
}


void getcurrentworkdir_c(char cwd[], int *stat ){
  char cwd_tmp[1024];
  if(getcwd(cwd_tmp, sizeof(cwd_tmp)) == cwd_tmp){
    strcpy(cwd,cwd_tmp);
    *stat = 0;
  }
  else{
    *stat = 1;
  }
}


void gethostname_c(char hostname[], int *stat){
  char hostname_tmp[1024];
  if(gethostname(hostname_tmp, sizeof(hostname_tmp)) == 0){
    strcpy(hostname,hostname_tmp);
    *stat = 0;
  }
  else{
    *stat = 1;
  }
}


int chdir_c(const char *dir){
  return chdir(dir);
}

void signalterm_c(void (*handler)(int)){
  signal(SIGTERM, handler);
}

void signalusr1_c(void (*handler)(int)){
  signal(SIGUSR1, handler);
}

void signalusr2_c(void (*handler)(int)){
  signal(SIGUSR2, handler);
}

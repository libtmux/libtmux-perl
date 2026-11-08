/* Author-only regression. Release the stopped command after its streams
 * close and Perl reaches the native wait, then leave the exit unreaped. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/select.h>
#include <sys/wait.h>
#include <signal.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
static int injected;
int select(int n, fd_set *reads, fd_set *writes, fd_set *excepts, struct timeval *timeout) {
    int (*real_select)(int,fd_set *,fd_set *,fd_set *,struct timeval *)=dlsym(RTLD_NEXT,"select");
    const char *root=getenv("LIBTMUX_PROBE_ROOT");
    int count=0;
    if (reads) for(int i=0;i<n;i++) count+=FD_ISSET(i,reads)!=0;
    if (!injected && root && getppid()==atoi(root) && count==3 && timeout && timeout->tv_usec>10000) {
        fd_set copy=*reads;
        struct timeval zero={0,0};
        if (real_select(n,&copy,NULL,NULL,&zero)==0) {
            char path[128]; snprintf(path,sizeof(path),"/proc/%d/task/%d/children",getpid(),getpid());
            FILE *f=fopen(path,"r"); int child=0;
            if(f) { if(fscanf(f,"%d",&child)!=1) child=0; fclose(f); }
            if(child>0) {
                injected=1;
                siginfo_t info; int rc;
                do { rc=waitid(P_PID,child,&info,WSTOPPED|WNOWAIT); } while(rc<0 && errno==EINTR);
                if(rc<0 || kill(child,SIGCONT)!=0) _exit(91);
                do { rc=waitid(P_PID,child,&info,WEXITED|WNOWAIT); } while(rc<0 && errno==EINTR);
                if(rc<0) _exit(92);
                write(2,"INJECTED_EXIT\n",14);
                rc=real_select(n,reads,writes,excepts,timeout);
                if(!rc) write(2,"LOST_WAKEUP\n",12);
                return rc;
            }
        }
    }
    return real_select(n,reads,writes,excepts,timeout);
}

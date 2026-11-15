/* Author-only injection: deliver a real child exit after Perl's final safe
 * point and before the blocking wait. WNOWAIT leaves reaping to IO::Async. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <poll.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <errno.h>
static int injected;
static void child_exit(void) {
    int fd=atoi(getenv("LIBTMUX_PROBE_GO_FD"));
    pid_t pid=(pid_t)atoi(getenv("LIBTMUX_PROBE_CHILD"));
    if (write(fd,"x",1)!=1) _exit(91);
    siginfo_t info;
    int rc;
    do { rc=waitid(P_PID,pid,&info,WEXITED|WNOWAIT); } while(rc<0 && errno==EINTR);
    if (rc<0) _exit(92);
}
int poll(struct pollfd *fds, nfds_t n, int timeout) {
    int (*real_poll)(struct pollfd *,nfds_t,int)=dlsym(RTLD_NEXT,"poll");
    if (!injected && timeout<0) {
        injected=1; child_exit(); write(2,"INJECTED_EXIT\n",14);
        int rc=real_poll(fds,n,200);
        if (!rc) write(2,"LOST_WAKEUP\n",12);
        return rc;
    }
    return real_poll(fds,n,timeout);
}
int ppoll(struct pollfd *fds,nfds_t n,const struct timespec *timeout,const sigset_t *mask) {
    int (*real_ppoll)(struct pollfd *,nfds_t,const struct timespec *,const sigset_t *)=dlsym(RTLD_NEXT,"ppoll");
    if (!injected && !timeout) {
        injected=1; child_exit(); write(2,"INJECTED_EXIT\n",14);
        struct timespec bound={0,200000000};
        int rc=real_ppoll(fds,n,&bound,mask);
        if (!rc) write(2,"LOST_WAKEUP\n",12);
        return rc;
    }
    return real_ppoll(fds,n,timeout,mask);
}

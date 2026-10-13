// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

#define _GNU_SOURCE
#include "ProcessSupport.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

struct id_process { atomic_bool cancelled; };

id_process *id_process_create(void) {
  id_process *p = calloc(1, sizeof(*p));
  if (p) atomic_init(&p->cancelled, 0);
  return p;
}
void id_process_cancel(id_process *p) { atomic_store(&p->cancelled, 1); }
void id_process_destroy(id_process *p) { free(p); }
void id_process_result_destroy(id_process_result *r) { free(r->out_bytes); free(r->err_bytes); }

static double now(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec + (double)t.tv_nsec / 1000000000.0;
}

static int consume(int fd, char **bytes, size_t *count, size_t limit) {
  char buffer[16384];
  ssize_t n = read(fd, buffer, sizeof(buffer));
  if (n == 0) return 1;
  if (n < 0) return (errno == EAGAIN || errno == EINTR) ? 0 : -1;
  if (*count > limit || (size_t)n > limit - *count) return -2;
  char *next = realloc(*bytes, *count + (size_t)n);
  if (!next) return -1;
  memcpy(next + *count, buffer, (size_t)n);
  *bytes = next; *count += (size_t)n;
  return 0;
}

id_process_result id_process_run(id_process *p, const char *executable,
                                char *const argv[], char *const env[],
                                const char *directory, double timeout,
                                size_t limit) {
  id_process_result r = {0};
  int pipes[2][2] = {{-1,-1},{-1,-1}};
  pid_t pid = -1;
  if (atomic_load(&p->cancelled)) { r.failure = 2; return r; }
  if (pipe(pipes[0]) || pipe(pipes[1])) { r.failure = 3; r.system_error = errno; goto cleanup; }
  for (int i = 0; i < 2; i++) {
    fcntl(pipes[i][0], F_SETFD, FD_CLOEXEC);
    fcntl(pipes[i][1], F_SETFD, FD_CLOEXEC);
    fcntl(pipes[i][0], F_SETFL, O_NONBLOCK);
  }
  posix_spawn_file_actions_t actions;
  posix_spawnattr_t attr;
  posix_spawn_file_actions_init(&actions);
  posix_spawnattr_init(&attr);
  int error = posix_spawn_file_actions_addchdir_np(&actions, directory);
  if (!error) error = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0);
  if (!error) error = posix_spawn_file_actions_adddup2(&actions, pipes[0][1], STDOUT_FILENO);
  if (!error) error = posix_spawn_file_actions_adddup2(&actions, pipes[1][1], STDERR_FILENO);
  #if defined(__linux__)
  if (!error) error = posix_spawn_file_actions_addclosefrom_np(&actions, 3);
  #endif
  if (!error) error = posix_spawnattr_setpgroup(&attr, 0);
  short flags = POSIX_SPAWN_SETPGROUP;
  #if defined(__APPLE__)
  flags |= POSIX_SPAWN_CLOEXEC_DEFAULT;
  #endif
  if (!error) error = posix_spawnattr_setflags(&attr, flags);
  if (!error) error = posix_spawnp(&pid, executable, &actions, &attr, argv, env);
  posix_spawn_file_actions_destroy(&actions);
  posix_spawnattr_destroy(&attr);
  if (error) { r.failure = 3; r.system_error = error; goto cleanup; }
  close(pipes[0][1]); pipes[0][1] = -1;
  close(pipes[1][1]); pipes[1][1] = -1;
  double start = now();
  int exited = 0, status = 0;
  while (!exited || pipes[0][0] >= 0 || pipes[1][0] >= 0) {
    if (atomic_load(&p->cancelled)) r.failure = 2;
    else if (now() - start >= timeout) r.failure = 1;
    if (r.failure) {
      // The dedicated process group includes compiler children and pipe holders.
      kill(-pid, SIGKILL);
      if (!exited) while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
      break;
    }
    struct pollfd fds[2] = {{pipes[0][0], POLLIN, 0}, {pipes[1][0], POLLIN, 0}};
    if (poll(fds, 2, 25) < 0 && errno != EINTR) { r.failure = 3; r.system_error = errno; continue; }
    for (int i = 0; i < 2; i++) {
      if (fds[i].fd < 0 || !fds[i].revents) continue;
      int result = consume(fds[i].fd, i == 0 ? &r.out_bytes : &r.err_bytes,
                           i == 0 ? &r.out_count : &r.err_count, limit);
      if (result == 1) { close(pipes[i][0]); pipes[i][0] = -1; }
      else if (result < 0) { r.failure = result == -2 ? 4 : 3; r.system_error = errno; }
    }
    if (!exited) {
      pid_t w = waitpid(pid, &status, WNOHANG);
      if (w == pid) exited = 1;
      else if (w < 0 && errno != EINTR) { r.failure = 3; r.system_error = errno; }
    }
  }
  r.exit_status = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
cleanup:
  for (int i = 0; i < 2; i++) for (int j = 0; j < 2; j++) if (pipes[i][j] >= 0) close(pipes[i][j]);
  return r;
}

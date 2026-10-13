#ifndef INTERFACE_DISTILLER_PROCESS_SUPPORT_H
#define INTERFACE_DISTILLER_PROCESS_SUPPORT_H
#include <stddef.h>
typedef struct id_process id_process;
typedef struct {
  char *out_bytes;
  size_t out_count;
  char *err_bytes;
  size_t err_count;
  int exit_status;
  int failure;
  int system_error;
} id_process_result;
id_process *id_process_create(void);
void id_process_cancel(id_process *process);
void id_process_destroy(id_process *process);
id_process_result id_process_run(id_process *process, const char *executable,
                                char *const argv[], char *const env[],
                                const char *directory, double timeout,
                                size_t output_limit);
void id_process_result_destroy(id_process_result *result);
#endif

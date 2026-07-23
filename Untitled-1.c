#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>
#include <pwd.h>
#include <limits.h>
#include <string.h>
#include <errno.h>
#include <sys/select.h>
#include <fcntl.h>

#include "command.h"
#include "execute.h"
#include "parser.h"
#include "parsing.h"
#include "builtin.h"
#include "tests/syscall_mock.h"

#ifndef HOST_NAME_MAX
#define HOST_NAME_MAX 64
#endif
#define MAX_BG_JOBS 128

// --- Variables Globales ---
static pid_t background_jobs[MAX_BG_JOBS];
static int job_count = 0;
static int self_pipe_fd[2]; // Pipe para comunicación segura: [0] lectura, [1] escritura

// --- Funciones de Utilidad ---
static char *truncar_path(const char *path, int n) { /* ... sin cambios ... */ }
static void show_prompt(void) { /* ... sin cambios ... */ }

// --- Manejo de Señales y Trabajos ---

/**
 * @brief Manejador de señales para SIGCHLD.
 *
 * Escribe un byte en el self-pipe para notificar al bucle main de forma asíncrona y segura.
 */
static void sigchld_handler(int sig) {
    char dummy = 'c';
    write(self_pipe_fd[1], &dummy, 1);
}

/**
 * @brief Revisa el estado de los trabajos en segundo plano.
 *
 * Itera sobre la lista de trabajos conocidos y usa waitpid con WNOHANG
 * para cosechar a los que hayan terminado, notificando al usuario.
 */
static void check_background_jobs(void) {
    int status;
    pid_t pid;
    bool notification_was_printed = false;

    for (int i = 0; i < job_count; i++) {
        pid = waitpid(background_jobs[i], &status, WNOHANG);
        if (pid == background_jobs[i]) {
            fprintf(stderr, "\n[+] Terminado (Job PID: %d)\n", pid);
            notification_was_printed = true;
            background_jobs[i] = background_jobs[job_count - 1];
            job_count--;
            i--;
        }
    }

    if (notification_was_printed) {
        show_prompt();
    }
}

// --- Bucle Principal ---
int main(int argc, char *argv[]) {
    pipeline pl;
    Parser input;
    bool quit = false;
    bool prompt_needed = true;

    // --- Configuración Inicial ---
    if (pipe(self_pipe_fd) == -1) {
        perror("pipe");
        exit(EXIT_FAILURE);
    }
    // Poner el pipe en modo no bloqueante para evitar cuelgues
    int flags = fcntl(self_pipe_fd[0], F_GETFL, 0);
    fcntl(self_pipe_fd[0], F_SETFL, flags | O_NONBLOCK);

    input = parser_new(stdin);
    signal(SIGCHLD, sigchld_handler);

    // --- Bucle de Eventos ---
    while (!quit) {
        check_background_jobs();

        if (prompt_needed) {
            show_prompt();
            prompt_needed = false;
        }

        fd_set readfds;
        FD_ZERO(&readfds);
        FD_SET(STDIN_FILENO, &readfds);      // Vigilar teclado
        FD_SET(self_pipe_fd[0], &readfds);   // Vigilar pipe de señales

        int max_fd = (STDIN_FILENO > self_pipe_fd[0]) ? STDIN_FILENO : self_pipe_fd[0];
        int result = select(max_fd + 1, &readfds, NULL, NULL, NULL);

        if (result < 0) {
            if (errno == EINTR) continue; // Interrupción por señal: normal, repetir
            perror("select");
            exit(EXIT_FAILURE);
        }

        // Evento: Un hijo terminó (notificación por el pipe)
        if (FD_ISSET(self_pipe_fd[0], &readfds)) {
            char dummy_buffer[MAX_BG_JOBS];
            while (read(self_pipe_fd[0], dummy_buffer, sizeof(dummy_buffer)) > 0); // Vaciar el pipe
        }

        // Evento: El usuario escribió un comando
        if (FD_ISSET(STDIN_FILENO, &readfds)) {
            pl = parse_pipeline(input);
            if (pl != NULL) {
                if (!pipeline_is_empty(pl)) {
                    bool is_background = !pipeline_get_wait(pl);
                    pid_t last_pid = execute_pipeline(pl);
                    if (is_background && last_pid > 0) {
                        if (job_count < MAX_BG_JOBS) {
                            background_jobs[job_count++] = last_pid;
                        } else {
                            fprintf(stderr, "Límite de trabajos en background alcanzado.\n");
                        }
                    }
                }
                pipeline_destroy(pl);
                pl = NULL;
            } else if (!parser_at_eof(input) && errno != EINTR) {
                fprintf(stderr, "mybash: Error de sintaxis.\n");
            }
            prompt_needed = true;
        }
        quit = parser_at_eof(input);
    }

    close(self_pipe_fd[0]);
    close(self_pipe_fd[1]);
    parser_destroy(input);
    return EXIT_SUCCESS;
}
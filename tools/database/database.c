/* A _very_ skeleton file to demonstrate building tagcache db on host. */

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>

#include "config.h"
#include "tagcache.h"
#include "dir.h"

#define MAX_STATIC_ROOTS 12
#define MAX_PATHNAME 80

/* This is meant to be run on the root of the dap. it'll put the db files into
 * a .rockbox subdir */

/* needed for io.c - declared here, used for path construction */
const char *sim_root_dir = ".";

/* Read "database scan paths" setting from config.cfg */
static int read_scan_paths(char *buffer, size_t bufsize, char **paths, int max_paths)
{
    FILE *f;
    char line[1024];
    char configpath[256];
    const char *setting = "database scan paths:";
    size_t setting_len = strlen(setting);
    int count = 0;

    /* Build path: sim_root_dir + /.rockbox/config.cfg */
    snprintf(configpath, sizeof(configpath), "%s/.rockbox/config.cfg", sim_root_dir);
    f = fopen(configpath, "r");
    if (!f) {
        fprintf(stderr, "Note: No config.cfg found at %s, scanning from root\n", configpath);
        return 0;
    }

    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, setting, setting_len) == 0) {
            char *value = line + setting_len;
            char *end;

            /* Skip leading whitespace */
            while (*value == ' ') value++;

            /* Remove trailing newline/whitespace */
            end = value + strlen(value) - 1;
            while (end > value && (*end == '\n' || *end == '\r' || *end == ' '))
                *end-- = '\0';

            if (*value == '\0') {
                break; /* Empty setting */
            }

            /* Copy to buffer and split on ':' */
            strncpy(buffer, value, bufsize - 1);
            buffer[bufsize - 1] = '\0';

            /* Split paths */
            char *token = strtok(buffer, ":");
            while (token && count < max_paths) {
                paths[count++] = token;
                token = strtok(NULL, ":");
            }
            break;
        }
    }

    fclose(f);
    return count;
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    char pathbuf[MAX_PATHNAME * MAX_STATIC_ROOTS];
    char *paths[MAX_STATIC_ROOTS + 1];
    int path_count;

    char rbdir_path[256];
    struct stat st;

    fprintf(stderr, "Rockbox database tool for '%s'\n\n", TARGET_NAME);

    /* Check for .rockbox directory using stat (avoids Rockbox's opendir wrapper) */
    snprintf(rbdir_path, sizeof(rbdir_path), "%s/.rockbox", sim_root_dir);
    if (stat(rbdir_path, &st) != 0 || !S_ISDIR(st.st_mode)) {
        fprintf(stderr, "Unable to find '%s' directory!\n", rbdir_path);
        fprintf(stderr, "This needs to be executed in your DAP's top-level directory!\n\n");
        return 1;
    }

    /* Try to read scan paths from config, fall back to "/" */
    path_count = read_scan_paths(pathbuf, sizeof(pathbuf), paths, MAX_STATIC_ROOTS);
    if (path_count == 0) {
        paths[0] = "/";
        path_count = 1;
    }
    paths[path_count] = NULL;

    fprintf(stderr, "Directories to scan:\n");
    for (int i = 0; i < path_count; i++) {
        fprintf(stderr, "  %s\n", paths[i]);
    }
    fprintf(stderr, "\n");

    tagcache_init();

    fprintf(stderr, "Scanning files (may take some time)...\n");

    do_tagcache_build((const char **)paths);
    tagcache_reverse_scan();

    fprintf(stderr, "...done!\n");

    return 0;
}


/* stubs to avoid including thread-sdl.c */
#include "kernel.h"
void mutex_init(struct mutex *m)
{
    (void)m;
}

void mutex_lock(struct mutex *m)
{
    (void)m;
}

void mutex_unlock(struct mutex *m)
{
    (void)m;
}

void sim_thread_lock(void *me)
{
    (void)me;
}

void * sim_thread_unlock(void)
{
    return (void*)1;
}

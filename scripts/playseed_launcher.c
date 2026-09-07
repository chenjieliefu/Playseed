// Local macOS launcher. The project stays beside Playseed.app.
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <libgen.h>

int main(int argc, char **argv) {
    char executable[PATH_MAX], resolved[PATH_MAX], root[PATH_MAX];
    char runtime[PATH_MAX], project[PATH_MAX];
    uint32_t size = sizeof executable;
    if (_NSGetExecutablePath(executable, &size) || !realpath(executable, resolved)) return 1;
    snprintf(root, sizeof root, "%s", resolved);
    for (int i = 0; i < 4; i++) {
        char parent[PATH_MAX];
        snprintf(parent, sizeof parent, "%s", dirname(root));
        snprintf(root, sizeof root, "%s", parent);
    }
    if (snprintf(runtime, sizeof runtime, "%s/Playseed.app/Contents/MacOS/PlayseedRuntime", root) >= sizeof runtime ||
        snprintf(project, sizeof project, "%s/app", root) >= sizeof project) return 1;
    if (chdir(root) || access(runtime, X_OK) || access("app/project.godot", R_OK)) {
        fprintf(stderr, "Keep Playseed.app inside the Playseed project folder.\n");
        return 1;
    }
    setenv("PLAYSEED_GODOT", runtime, 1);
    if (argc > 1 && strncmp(argv[1], "-psn_", 5)) {
        argv[0] = runtime;
        execv(runtime, argv);
        return 1;
    }
    char *args[] = {runtime, "--path", project, NULL};
    execv(runtime, args);
    return 1;
}

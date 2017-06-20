#define _BSD_SOURCE
#include <stdio.h>
#include <unistd.h>

// To build:
// cc -std=c99 safe_unzip_wrapper.c -o safe_unzip_wrapper && sudo chown root safe_unzip_wrapper && sudo chmod a+s safe_unzip_wrapper

int main(int argc, char **v, char **e) {
  int rc; const char *m;
  const char *newroot = NULL;
  const char *zipfile = NULL;
  const char *usage = "Usage: safe_unzipper -d DIR-TO-UNZIP-IN -f ZIPFILE";
  int num_errs = 0;

  for (int i = 1; i <= argc - 1; i++) {
    char *arg = v[i];
    if (arg[0] == '-') {
      if (arg[1] == 'f') {
        if (zipfile) {
	  fprintf(stderr, "input zipfile of %s already set, trying to set it to %s\n", zipfile, v[i + 1]);
	  num_errs += 1;
	}
	zipfile = v[i + 1];
	i += 1;
      }  else if (arg[1] == 'd') {
        if (newroot) {
	  fprintf(stderr, "input newroot of %s already set, trying to set it to %s\n", newroot, v[i + 1]);
	  num_errs += 1;
	}
	newroot = v[i + 1];
	i += 1;
      } else {
        fprintf(stderr, "unexpected option of -%s (usage:%s)\n", arg, usage);
      }
    } else {
      fprintf(stderr, "unexpected option of -%s (usage:%s)\n", arg, usage);
    }
  }
  if (!zipfile) {
    fprintf(stderr, "No -f ZIPFILE option specified\n");
    num_errs += 1;
  }
  if (!newroot) {
    fprintf(stderr, "No -d EXTRACTION_DIR option specified\n");
    num_errs += 1;
  }
  if (num_errs > 0) {
    return 1;
  }
  const char * const cmd_args[] = {"-o", "-qq", "-:", zipfile};
  fprintf(stderr, "zipfile: %s\n", cmd_args[2]);

    if ( (m="chdir" ,rc=chdir(newroot)) == 0
      && (m="chroot",rc=chroot(newroot)) == 0
      && (m="setuid",rc=setuid(getuid())) == 0 ) {
            m="execve", execve("/bin/unzip", (char * const *) cmd_args, e);
    }
    perror(m);
    return 0;
}


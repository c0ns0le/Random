
/*
**++
**  Call the Isilon quota retreiver script
**
**      This is a setuid root program that runs the Isilon quota script.  This is needed as that script needs
**      to read a stashed password file which is only readable as root.
**
**--
*/

/*
**
**  Include files
**
*/

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>
#include <sys/types.h>
#include <unistd.h>
#include <wait.h>

/*
**
**  Macros
**
*/

#define ID "call_isilon_quota"

#define SCRIPT "isilon_quota"

/*
**
**  Global data , declarations & definitions
**
*/

/*
** Functions
*/

int Usage()
{
  fprintf( stderr, "Usage: %s <username>\n", ID );
  return 1;
}

/*
**  Main program
*/

int main( int argc, char *argv[] )
{
  char C;

  char *CP;

  int ChildStatus,
    FD,
    Status;

  pid_t pid;

  uid_t uid;

  if ( argc != 2 )
    {
      exit( Usage() );
    }

  /* Validate the specified username syntactically */

  CP = argv[1];

  if ( strlen( CP ) > 16 )
    exit( Usage() );

  while ( C = *CP++ )
    {
      if ( !isalnum( C ) )
        exit( Usage() );
    }

  close( 0 );
//   close( 1 );
//   close( 2 );

  FD = open( "/dev/null", O_RDWR, 0 );

  if ( FD != 0 )
    {
      exit(1);
    }

//   dup2( 0, 1 );
//   dup2( 0, 2 );

  if ( setuid(0) )
    {
      syslog( LOG_ERR, "%s setuid(0) failed", ID );
      exit(1);
    }

  if( setgid(0) )
    {
      syslog( LOG_ERR, "%s setgid(0) failed", ID );
      exit(1);
    }

  /* Execute Python script */

  pid = fork();
  if ( pid < 0 )
    {
      syslog( LOG_ERR, "%s : fork failure; errno is %d", ID, errno );
      exit(1);
    }

  if( !pid )
    {
      /* In child process */

      if ( execl( SCRIPT, SCRIPT, argv[1], (char *) NULL ) )
        {
          syslog( LOG_ERR, "%s : execl() Python call failed with errno %d", ID, errno );
          exit(1);
        }
    }

  /* In parent process */

  pid = waitpid( pid, &Status, 0 );

  if ( pid < 1 )
    {
      syslog( LOG_ERR, "%s : waitpid returned unexpected status of %d", ID, pid );
      exit(1);
    }

  if ( WIFSIGNALED( Status ) )
    {
      syslog( LOG_ERR, "%s : child process %d received unexpected signal %d", ID, pid, WTERMSIG( Status ) );
      exit(1);
    }

  if ( !WIFEXITED( Status ) )
    {
      syslog( LOG_ERR, "%s : waitpid() returned but child neither exited nor was signalled; status %08x", ID, Status );
      exit(1);
    }

  ChildStatus = WEXITSTATUS( Status );

  if ( ChildStatus )
    {
      syslog( LOG_ERR, "%s : Python child process exited with %d", ID, ChildStatus );
      exit(1);
    }

    exit(0);
}

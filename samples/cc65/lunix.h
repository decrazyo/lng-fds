#define FILENO_STDIN  0
#define FILENO_STDOUT 1
#define FILENO_STDERR 2

int __fastcall__ close(int fd);
size_t __fastcall__ write(int fd,char *buf,size_t count);

 

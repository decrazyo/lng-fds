
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/types.h>
#include <sys/stat.h>

#define MIN(a,b) (((a)<(b))?(a):(b))

void usage(FILE* stream, char* progname) {
    fprintf(stream, "Usage: %s [#inth] <outfile.bin> <infile.nintendo>\n", progname);
    fprintf(stream, "Convert *.nintendo files into fwNES FDS block 3 and 4 pairs.\n");
    fprintf(stream, "\n");
    fprintf(stream, "\t-#\t<file_number>\tfile number in the range [0,255].\n");
    fprintf(stream, "\t-i\t<file_id>\tfile ID in the range [0,255].\n");
    fprintf(stream, "\t-n\t<file_name>\tfile name up to 8 chars long.\n");
    fprintf(stream, "\t-t\t<file_type>\tfile type in the range [0,2]. 0=PRAM(default), 1=CRAM, 2=VRAM.\n");
    fprintf(stream, "\t-a\t<file_address>\taddress that the FDS BIOS will load the file at.\n");
    fprintf(stream, "\t\t\tif omitted, the first 2 bytes of the input file is assumed to be the address.\n");
    fprintf(stream, "\t-s\t<file_size>\tnumber of bytes to copy from the input file.\n");
    fprintf(stream, "\t-h\t\tprint this help and exit.\n");
}


int main(int argc, char* argv[]) {

    char opt;
    char* file_num_opt = NULL;
    char* file_id_opt = NULL;
    char* file_name_opt = NULL;
    char* file_type_opt = NULL;
    char* file_addr_opt = NULL;
    char* file_size_opt = NULL;

    while ((opt = getopt(argc, argv, "#:i:n:t:a:s:h")) != -1) {
        switch (opt) {
            case '#':
                file_num_opt = optarg;
                break;
            case 'i':
                file_id_opt = optarg;
                break;
            case 'n':
                file_name_opt = optarg;
                break;
            case 't':
                file_type_opt = optarg;
                break;
            case 'a':
                file_addr_opt = optarg;
                break;
            case 's':
                file_size_opt = optarg;
                break;
            case 'h':
                usage(stdout, argv[0]);
                return 0;
        }
    }

    if (argc - optind != 2) {
        fprintf(stderr, "Error: missing positional argument(s)\n");
        usage(stderr, argv[0]);
        return 1;
    }

    char* outfile_name = argv[optind];
    char* infile_name = argv[optind+1];


    FILE* infile = fopen(infile_name, "r");

    if (!infile) {
        fprintf(stderr, "Error: could not open input file '%s'\n", infile_name);
        return 1;
    }

    struct stat st;
    fstat(fileno(infile), &st);

    if (!file_addr_opt && st.st_size < 2) {
        fprintf(stderr, "Error: input file '%s' is too small.\n", infile_name);
        return 1;
    }

    size_t file_size;
    size_t max_size;

    if (file_size_opt) {
        file_size = strtol(file_size_opt, NULL, 0);
        max_size = st.st_size;

        if (!file_addr_opt) {
            max_size -= 2;
        }
    }
    else {
        file_size = st.st_size;
        max_size = 0xffff;

        if (!file_addr_opt) {
            file_size -= 2;
        }
    }

    if (file_size > max_size) {
        fprintf(stderr, "Error: input file '%s' is too large.\n", infile_name);
        return 1;
    }

    FILE* outfile = fopen(outfile_name, "w");

    if (!outfile) {
        fprintf(stderr, "Error: could not open output file '%s'\n", outfile_name);
        return 1;
    }

    // file header (block 3) fields.
    uint8_t block_code = 0x03;
    uint8_t file_num = 0x00;
    uint8_t file_id = 0x00;
    uint8_t file_name[8];
    uint8_t file_addr_lo;
    uint8_t file_addr_hi;
    uint8_t file_size_lo;
    uint8_t file_size_hi;
    uint8_t file_type = 0x00; // default to program file

    if (file_num_opt) {
        file_num = strtol(file_num_opt, NULL, 0);
    }

    if (file_id_opt) {
        file_id = strtol(file_id_opt, NULL, 0);
    }


    size_t file_name_length;
    memset(file_name, ' ', sizeof(file_name));

    if (file_name_opt) {
        file_name_length = strlen(file_name_opt);

        if (file_name_length > sizeof(file_name)) {
            fprintf(stderr, "Warning: file name too long. truncating to 8 bytes.");
        }

        memcpy(file_name, file_name_opt, MIN(file_name_length, sizeof(file_name)));
    }
    else {
        // derive the file name from the output file name.
        const char* file_basename = basename(outfile_name);
        const char* file_extension = strrchr(file_basename, '.');

        if (file_extension) {
            file_name_length = file_extension - file_basename;
        }
        else {
            file_name_length = strlen(file_basename);
        }

        memcpy(file_name, basename(outfile_name), MIN(file_name_length, sizeof(file_name)));
    }

    if (file_addr_opt) {
        size_t file_addr = strtol(file_addr_opt, NULL, 0);

        if (file_addr > 0xffff) {
            fprintf(stderr, "Warning: file address too large. truncating to 2 bytes.");
        }

        file_addr_lo = file_addr & 0xff;
        file_addr_hi = (file_addr>>8) & 0xff;
    }
    else {
        file_addr_lo = fgetc(infile);
        file_addr_hi = fgetc(infile);
    }

    file_size_lo = file_size & 0xff;
    file_size_hi = (file_size & 0xff00) >> 8;

    if(file_type_opt) {
        file_type = strtol(file_type_opt, NULL, 0);
        if (file_type > 2) {
            fprintf(stderr, "Warning: invalid file type. using it anyway.");
        }
    }

    // write out block 3
    fputc(block_code, outfile);
    fputc(file_num, outfile);
    fputc(file_id, outfile);
    fwrite(file_name, 1, sizeof(file_name), outfile);
    fputc(file_addr_lo, outfile);
    fputc(file_addr_hi, outfile);
    fputc(file_size_lo, outfile);
    fputc(file_size_hi, outfile);
    fputc(file_type, outfile);


    // file data (block 4)
    block_code = 0x04;

    fputc(block_code, outfile);

    for (size_t i=0; i < file_size; i++) {
        fputc(fgetc(infile), outfile);
    }

    fclose(outfile);
    fclose(infile);

    return 0;
}

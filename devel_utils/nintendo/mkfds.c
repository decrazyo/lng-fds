
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <sys/types.h>
#include <sys/stat.h>

#define MIN(a,b) (((a)<(b))?(a):(b))


void usage(FILE* stream, char* progname) {
    fprintf(stream, "Usage: %s [b#iHh] <outfile.fds> <infile.bin...>\n", progname);
    fprintf(stream, "Create a fwNES FDS file.\n");
    fprintf(stream, "\n");
    fprintf(stream, "\t-b\t<boot_files>\tboot file number in the range [0,255].\n");
    fprintf(stream, "\t\t\tfiles with an ID <= boot_files will be loaded at boot.\n");
    fprintf(stream, "\t-#\t\tgive input files sequential file numbers.\n");
    fprintf(stream, "\t-i\t\tgive input files sequential file IDs.\n");
    fprintf(stream, "\t-H\t\tomit fwNES FDS file header.\n");
    fprintf(stream, "\t-h\t\tprint this help and exit.\n");
}


int main(int argc, char* argv[]) {

    char opt;
    char* boot_files_opt = NULL;
    bool seq_file_id = false;
    bool seq_file_num = false;
    bool omit_header = false;

    while ((opt = getopt(argc, argv, "b:#iHh")) != -1) {
        switch (opt) {
            case 'b':
                boot_files_opt = optarg;
                break;
            case '#':
                seq_file_id = true;
                break;
            case 'i':
                seq_file_num = true;
                break;
            case 'H':
                omit_header = true;
                break;
            case 'h':
                usage(stdout, argv[0]);
                return 0;
        }
    }

    if (argc - optind < 2) {
        fprintf(stderr, "Error: missing positional argument(s)\n");
        usage(stderr, argv[0]);
        return 1;
    }

    char* outfile_name = argv[optind++];
    FILE* outfile = fopen(outfile_name, "w");

    if (!outfile) {
        fprintf(stderr, "Error: could not open output file '%s'\n", outfile_name);
        return 1;
    }

    // TODO: make more of this stuff configurable with command line arguments.

    if (!omit_header) {
        uint8_t constant[] = {0x46, 0x44, 0x53, 0x1A};
        uint8_t disk_sides = 1;
        uint8_t padding[] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
        fwrite(constant, 1, sizeof(constant), outfile);
        fputc(disk_sides, outfile);
        fwrite(padding, 1, sizeof(padding), outfile);
    }

    // disk info (block 1) fields.
    uint8_t block_code = 0x01;
    char disk_verification[] = "*NINTENDO-HVC*"; // don't include NULL terminator.
    uint8_t licensee_code = 0x00; // unlicensed.
    char game_name[] = "LNG"; // don't include NULL terminator.
    uint8_t game_type = ' '; // normal disk.
    uint8_t game_version = 0x00;
    uint8_t side_number = 0x00; // side A
    uint8_t disk_number = 0x00; // first disk
    uint8_t disk_type = 0x00;
    uint8_t unknown1 = 0x00;
    uint8_t boot_files = 0x00;
    uint8_t unknown2[] = {0xff, 0xff, 0xff, 0xff, 0xff};
    uint8_t manufacturing_date[] = {0x24, 0x01, 0x01}; // TODO: insert the current date.
    uint8_t country_code = 0x49; // japan.
    uint8_t unknown3 = 0x61;
    uint8_t unknown4 = 0x00;
    uint8_t unknown5[] = {0x00, 0x02};
    uint8_t unknown6[] = {0x00, 0x1b, 0x00, 0x97, 0x00}; // game info? copied from SMB2.
    uint8_t rewritten_date[] = {0x24, 0x01, 0x01}; // TODO: insert the current date.
    uint8_t unknown7 = 0xff; // copied from SMB2.
    uint8_t unknown8 = 0x80;
    uint8_t disk_writer_sn[] = {0xff, 0xff};
    uint8_t unknown9 = 0x07;
    uint8_t rewrite_count = 0x00;
    uint8_t actual_disk_side = 0x00; // side A
    uint8_t disk_type_other = 0x00; // yellow disk
    uint8_t disk_version = 0x00;


    uint8_t file_amount = argc - optind;

    if(boot_files_opt) {
        boot_files = atoi(boot_files_opt);
    }
    else {
        boot_files = file_amount - 1;
    }


    // write out block 1
    fputc(block_code, outfile);
    fwrite(disk_verification, 1, strlen(disk_verification), outfile);
    fputc(licensee_code, outfile);
    fwrite(game_name, 1, strlen(game_name), outfile);
    fputc(game_type, outfile);
    fputc(game_version, outfile);
    fputc(side_number, outfile);
    fputc(disk_number, outfile);
    fputc(disk_type, outfile);
    fputc(unknown1, outfile);
    fputc(boot_files, outfile);
    fwrite(unknown2, 1, sizeof(unknown2), outfile);
    fwrite(manufacturing_date, 1, sizeof(manufacturing_date), outfile);
    fputc(country_code, outfile);
    fputc(unknown3, outfile);
    fputc(unknown4, outfile);
    fwrite(unknown5, 1, sizeof(unknown5), outfile);
    fwrite(unknown6, 1, sizeof(unknown6), outfile);
    fwrite(rewritten_date, 1, sizeof(rewritten_date), outfile);
    fputc(unknown7, outfile);
    fputc(unknown8, outfile);
    fwrite(disk_writer_sn, 1, sizeof(disk_writer_sn), outfile);
    fputc(unknown9, outfile);
    fputc(rewrite_count, outfile);
    fputc(actual_disk_side, outfile);
    fputc(disk_type_other, outfile);
    fputc(disk_version, outfile);


    // file amount (block 2)
    block_code = 0x02;

    fputc(block_code, outfile);
    fputc(file_amount, outfile);


    // append blocks 3 and 4 from user specified files.
    uint8_t file_id = 0;
    uint8_t file_num = 0;

    char* infile_name;
    FILE* infile;
    struct stat st;
    char data;

    for (int j = optind; j < argc; j++) {
        infile_name = argv[j];
        infile = fopen(infile_name, "r");

        if (!infile) {
            fprintf(stderr, "Error: could not open input file '%s'\n", infile_name);
            return 1;
        }

        fstat(fileno(infile), &st);

        for (int i = 0; i < st.st_size; i++) {
            data = fgetc(infile);

            // adjust file numbers/IDs.
            if(seq_file_num && i == 1) {
                fputc(file_num++, outfile);
                continue;
            }

            if(seq_file_id && i == 2) {
                fputc(file_id++, outfile);
                continue;
            }

            fputc(data, outfile);
        }

        fclose(infile);
    }

    fclose(outfile);

    return 0;
}

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// internal testing with tool ig;

// type definition for boolean linear logic emulation
typedef uint8_t bool;
#define true 1  // upstream
#define false 0 // downstream
// Anurag loves his bestfriend and his bestfriend loves him too
typedef struct
{
    /* data: boot-sector header */
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;
    //  i barely have an idea of why i defined sectors per cluster honestly!
    uint8_t DriveNumber;
    uint8_t Reserved;
    uint8_t Signature;
    uint32_t VolumeId;
    uint8_t VolumeLabel[11];
    uint8_t SystemId[8];

} __attribute__((packed)) BootSector;

typedef struct
{
    /* data */
    uint8_t Name[11];
    uint8_t Attributes;

    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t Accesseddate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;

    uint16_t FirstClusterLow;

    uint32_t size;
} __attribute__((packed)) DirectoryEntry;

BootSector g_BootSector;
uint8_t *g_fat = NULL;
DirectoryEntry *g_RootDirectory = NULL;

/**
 * @brief Reads the boot sector from the disk.
 * 
 * @param disk The disk file pointer.
 * @return true if the boot sector is read successfully, false otherwise.
 */
bool readBootSector(FILE *disk)
{
    return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;
}

/**
 * @brief Reads sectors from the disk.
 * 
 * @param disk The disk file pointer.
 * @param lba The logical block address of the first sector to read.
 * @param count The number of sectors to read.
 * @param bufferOut The buffer to store the read data.
 * @return true if the sectors are read successfully, false otherwise.
 */
bool readSectors(FILE *disk, uint32_t lba, uint32_t count, void *bufferOut)
{
    bool ok = true;
    ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count);
    return ok;
}

/**
 * @brief Reads the File Allocation Table (FAT) from the disk.
 * 
 * @param disk The disk file pointer.
 * @return true if the FAT is read successfully, false otherwise.
 */
bool readFat(FILE *disk)
{
    g_fat = (uint8_t *)malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_fat);
}

/**
 * @brief Reads the root directory from the disk.
 * 
 * @param disk The disk file pointer.
 * @return true if the root directory is read successfully, false otherwise.
 */
bool readRootDirectory(FILE *disk)
{
    uint16_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;
    uint32_t sectors = size / g_BootSector.BytesPerSector;
    if (size % g_BootSector.BytesPerSector > 0)
    {
        // Handle the case when the size is not a multiple of the sector size
    }
    // TODO: Implement the logic to read the root directory
}

int main(int argc, char **argv)
{
    if (argc > 3)
    {
        fprintf("Syntax: %s  <disk image>  <file name>\n", argv[0]);
        return -1;
    }

    FILE *disk = fopen(argv[1], "rb");
    if (!disk)
    {
        fprintf(stderr, "cannot open specified disk image %s!", argv[1]);
        return -1;
    }

    if (!readBootSector(disk))
    {
        fprintf(stderr, "could not read boot sector\n");
        return -1;
    }

    if (!readFat(disk))
    {
        fprintf(stderr, "could not read FAT\n");
        free(g_fat); 
        return -3;
    }

    free(g_fat);
    return 0;
}

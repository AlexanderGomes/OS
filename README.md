# Hobby OS Project

## Table of Contents

1. [Floppy Disk](#floppy-disk)
2. [FAT Support](#fat-support)
   - [Key Components](#key-components)
     - [Definitions and Structures](#definitions-and-structures)
     - [Constants](#constants)
     - [Initialization Functions](#initialization-functions)
     - [File and Directory Operations](#file-and-directory-operations)
   - [Usage](#usage)
3. [Bootloader Stage 1](#bootloader-stage-1)
   - [Key Concepts](#key-concepts)
     - [FAT12 File System](#fat12-file-system)
   - [Detailed Description](#detailed-description)
4. [Bootloader Stage 2](#bootloader-stage-2)
   - [Assembly Code Overview](#assembly-code-overview)
   - [C Code Overview](#c-code-overview)
   - [Key Points](#key-points)
5. [Kernel](#kernel)
   - [Initialization Process](#initialization-process)
   - [Input/Output Operations](#inputoutput-operations)
   - [Technical Details](#technical-details)

## Floppy Disk

The `main_floppy.img` file is formatted as a floppy disk containing the FAT12 file system. It holds the bootloader in its reserved sector and the kernel in its directories.

## FAT Support

The FAT (File Allocation Table) support module provides functionality to read from and interact with a FAT12 file system. This implementation allows the OS to:
- Read the boot sector and FAT table from a disk.
- Initialize and open the root directory.
- Open and read files from the file system.
- Traverse directories and handle file paths.

### Key Components

#### Definitions and Structures

- **FAT_BootSector**: Structure representing the boot sector of a FAT file system, containing metadata about the file system layout.
- **FAT_FileData**: Structure used to manage file-specific information, including its current position, buffer, and cluster information.
- **FAT_Data**: Central structure holding the boot sector data, root directory, and opened files.

#### Constants

- **SECTOR_SIZE**: Defines the size of a sector (512 bytes).
- **MAX_PATH_SIZE**: Maximum length of a file path (256 characters).
- **MAX_FILE_HANDLES**: Maximum number of simultaneously open file handles (10).
- **ROOT_DIRECTORY_HANDLE**: Handle identifier for the root directory (-1).
- **MEMORY_FAT_SIZE**: Maximum size of the memory allocated for FAT (0x10000).

#### Initialization Functions

##### FAT_ReadBootSector

Reads the boot sector from the disk.

```c
bool FAT_ReadBootSector(DISK* disk);
```

##### FAT_ReadFat

Reads the FAT table from the disk.

```c
bool FAT_ReadFat(DISK* disk);
```

##### FAT_Initialize

Initializes the FAT file system by reading the boot sector and FAT table, then sets up the root directory.

```c
bool FAT_Initialize(DISK* disk);
```

#### File and Directory Operations

##### FAT_ClusterToLba

Converts a cluster number to an LBA (Logical Block Address).

```c
uint32_t FAT_ClusterToLba(uint32_t cluster);
```

##### FAT_OpenEntry

Opens a directory entry and returns a handle to the file.

```c
FAT_File* FAT_OpenEntry(DISK* disk, FAT_DirectoryEntry* entry);
```

##### FAT_NextCluster

Gets the next cluster in the FAT chain.

```c
uint32_t FAT_NextCluster(uint32_t currentCluster);
```

##### FAT_Read

Reads data from an open file.

```c
uint32_t FAT_Read(DISK* disk, FAT_File* file, uint32_t byteCount, void* dataOut);
```

##### FAT_ReadEntry

Reads a directory entry from a file.

```c
bool FAT_ReadEntry(DISK* disk, FAT_File* file, FAT_DirectoryEntry* dirEntry);
```

##### FAT_Close

Closes an open file.

```c
void FAT_Close(FAT_File* file);
```

##### FAT_FindFile

Finds a file within a directory.

```c
bool FAT_FindFile(DISK* disk, FAT_File* file, const char* name, FAT_DirectoryEntry* entryOut);
```

##### FAT_Open

Opens a file by its path.

```c
FAT_File* FAT_Open(DISK* disk, const char* path);
```

### Usage

To use the FAT support functions, the disk must first be initialized with `FAT_Initialize`. After initialization, files can be opened and read using the provided file operations. For example:

```c
DISK disk;
if (FAT_Initialize(&disk)) {
    FAT_File* file = FAT_Open(&disk, "/path/to/file.txt");
    if (file) {
        char buffer[512];
        FAT_Read(&disk, file, sizeof(buffer), buffer);
        FAT_Close(file);
    }
}
```

## Bootloader Stage 1

The Stage 1 bootloader is the initial code executed when a computer starts up from a floppy disk. It is responsible for loading the FAT12 metadata, reading the root directory, and subsequently loading the Stage 2 bootloader (kernel) into memory. The bootloader operates in a 16-bit real mode environment and interacts with the BIOS to read data from the disk.

## Key Concepts

### FAT12 File System

- **Boot Sector**: Contains metadata about the file system, including the number of sectors per cluster, the total number of sectors, and the location of the FAT and root directory.
- **FAT Table**: Keeps track of the allocation status of clusters.
- **Root Directory**: Holds directory entries, each representing a file or subdirectory.

## Detailed Description

### Initialization

The bootloader starts by setting up the data segments (`ds` and `es`) and the stack (`ss` and `sp`). This ensures that the CPU operates in a known state and can correctly handle function calls and data manipulation.

### Reading the Boot Sector

The boot sector is read from the disk's first sector (LBA 0) using BIOS interrupts. The boot sector contains essential metadata such as the number of bytes per sector, the number of sectors per cluster, and the number of FAT tables.

### Locating the Root Directory

The root directory's location is calculated based on the reserved sectors, the number of FAT tables, and the size of each FAT table. This calculation allows the bootloader to determine the starting LBA of the root directory.

### Loading the Stage 2 Bootloader

The bootloader searches for the `STAGE2.BIN` file in the root directory. Once found, it reads the file's clusters, follows the FAT chain to read subsequent clusters if necessary, and loads the file into a predefined memory location.

### Transferring Control

After successfully loading the Stage 2 bootloader, control is transferred to it by setting the instruction pointer to the entry point of the loaded code.

## Bootloader Stage 2

The second stage of this bootloader is responsible for transitioning from real mode to protected mode, initializing the system, and loading the operating system kernel from a FAT file system.

### Assembly Code Overview

**entry.asm**

- **Initial Setup (16-bit real mode)**
    - `cli`: Disable interrupts to prevent interference during setup.
    - Save the boot drive number to `g_BootDrive`.
    - Set up the stack by aligning the stack segment (`ss`) and stack pointer (`sp`).
- **Transition to Protected Mode**
    - Call `EnableA20` to enable the A20 line, allowing access to memory above 1MB.
    - Call `LoadGDT` to load the Global Descriptor Table (GDT), which defines the memory segments for protected mode.
    - Set the protection enable flag in control register 0 (`cr0`) to enable protected mode.
    - Perform a far jump to `pmode` to switch to protected mode.
- **Protected Mode Setup (32-bit)**
    - Set up segment registers (`ds`, `ss`) with appropriate segment selectors.
    - Clear the BSS section (uninitialized data) by setting it to zero.
    - Pass the boot drive number to the kernel start function (`start`).
    - Halt the system.

**x86.asm**

- **Macros for Mode Switching**
    - `x86_EnterRealMode`: Switch from protected mode to real mode.
    - `x86_EnterProtectedMode`: Switch from real mode to protected mode.
    - `LinearToSegOffset`: Convert a linear address to a segment:offset address.
- **Disk I/O Functions**
    - `x86_outb`: Output a byte to a port.
    - `x86_inb`: Input a byte from a port.
    - `x86_Disk_GetDriveParams`: Get disk drive parameters using BIOS interrupt 13h.
    - `x86_Disk_Reset`: Reset the disk drive using BIOS interrupt 13h.
    - `x86_Disk_Read`: Read sectors from the disk using BIOS interrupt 13h.

### C Code Overview

**main.c**

- **Kernel Load and Execution**
    - Define memory locations for loading the kernel.
    - `start` function:
        - Clear the screen.
        - Initialize the disk using `DISK_Initialize`.
        - Initialize the FAT file system using `FAT_Initialize`.
        - Load the kernel from the FAT file system into memory.
        - Execute the kernel by calling its entry point.

### Key Points

- **Mode Switching**: The bootloader switches from real mode to protected mode to take advantage of 32-bit addressing and features.
- **A20 Line**: Enabling the A

20 line is crucial for accessing extended memory beyond the first 1MB.
- **GDT Setup**: The GDT defines memory segments used in protected mode.
- **Disk I/O**: The bootloader uses BIOS interrupts for disk operations to load the kernel.
- **Kernel Execution**: After loading the kernel into memory, the bootloader transfers control to the kernel's entry point to start the operating system.

## Kernel

The kernel is the core component of the operating system responsible for managing system resources and providing essential services to applications and hardware. This section outlines the initialization process of the kernel, focusing on the setup and execution flow from the bootloader to the main kernel functions.

### Initialization Process

1. **Transition from Bootloader to Kernel**
    - After the bootloader completes its tasks, such as enabling the A20 line and switching to protected mode, it calls the `start` function of the kernel.
    - The `start` function is marked with a custom section attribute (`.entry`) to ensure it is located correctly in memory.
2. **Memory Setup**
    - **BSS Section Clearing**:
        - The BSS section, which contains uninitialized data, must be cleared to zero. This is achieved by calling `memset` with the start and end addresses of the BSS section (`__bss_start` and `__end`).
        - This ensures all variables in the BSS section are initialized to zero before the kernel starts executing further code.
    - **Stack Setup**:
        - The bootloader already sets up the stack in protected mode. The kernel uses this pre-configured stack for its operations.
3. **Screen Management**
    - **Clearing the Screen**:
        - The `clrscr` function is called to clear the screen. This ensures a clean slate for displaying any output from the kernel.
    - **Printing to the Screen**:
        - The `printf` function is used to display a welcome message: "Hello world from kernel!!!". This serves as a simple confirmation that the kernel has successfully started.
4. **Infinite Loop**
    - At the end of the `start` function, the kernel enters an infinite loop to prevent the CPU from executing any unintended instructions. This is a common technique in bootstrapping processes to ensure the system remains in a known state.

### Input/Output Operations

The kernel includes basic I/O operations for interacting with hardware ports. These functions are defined in `x86.asm` and are essential for low-level hardware communication.

- **`x86_outb` Function**:
    - This function sends a byte to a specified port.
    - **Parameters**:
        - `dx`: The port number.
        - `al`: The byte to be sent.
    - The function reads the parameters from the stack, moves the byte to the port, and returns.
- **`x86_inb` Function**:
    - This function reads a byte from a specified port.
    - **Parameters**:
        - `dx`: The port number.
    - The function reads the port number from the stack, reads the byte from the port, and returns the value in `al`.

### Technical Details

- **Protected Mode**:
    - The kernel operates in protected mode, a 32-bit mode that provides advanced features like virtual memory, paging, and safe multitasking.
    - Protected mode enables the use of more than 1MB of memory, essential for modern operating systems.
- **Segment Descriptors**:
    - Memory segments are defined using segment descriptors loaded by the bootloader. These descriptors specify the base address, limit, and access rights for each segment.
- **GDT and IDT**:
    - The Global Descriptor Table (GDT) and Interrupt Descriptor Table (IDT) are crucial for managing memory and handling interrupts in protected mode.
    - While the GDT is set up by the bootloader, the kernel typically initializes the IDT to handle exceptions and hardware interrupts.

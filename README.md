# Linux Recycle Bin System

## Author
Margarida Almeida Cardoso - 125799
Enrique Alejandro Iriza de Ornelas - 124762

## Description
This project consists of implementing a Recycle Bin system for Linux, inspired by the Windows Recycle Bin functionality. Developed in Bash Shell Script, the system allows users to safely delete files with the possibility of restoring them before permanent removal. It includes features such as metadata logging, file listing and search capabilities, and automatic cleanup.

## Installation
Instruction to make the script executable:
- Command: "chmod u+x recycle_bin.sh"

## Usage
[How to use with examples] NAO SEIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII

## Features
### Core Features
-Feature 1: Initialize Recycle Bin
-Feature 2: Delete Files/Directories
-Feature 3: List Recycle Bin Contents
-Feature 4: Restore Files
-Feature 5: Search Files
-Feature 6: Empty Recycle Bin
-Feature 7: Help System
### Extra Features
-Feature 8: Statistics Dashboard
-Feature 9: Auto-Cleanup

## Configuration
The recycle bin system uses a configuration file located at ~/.recycle_bin/config. This file defines key operational settings that control how the system behaves.

Available Settings:
- AUTO_CLEANUP_DAYS=30 Number of days a file remains in the recycle bin before being eligible for automatic deletion.
- MAX_SIZE_MB=1024 Maximum total size (in megabytes) allowed for the recycle bin. If exceeded, the system will warn the user and prevent further deletions.

How to Edit these settings?
Run any of the recycle_bin features:
eg: ./recycle_bin.sh help
Open the configuration file with a text editor:
eg: nano ~/.recycle_bin/config
And edit it!


## Examples
[Detailed usage examples with screenshots]

## Known Issues
[Any limitations or bugs]

## References
#### External code snippets
#(>3 lines): Cite the source – IEEE template
### AI assistance
#Mention in README which parts were assisted
### Online resources
#List in references section – IEEE template
